###
BEAUTIFUL DOCS
Copyright (C) 2012 Maxime Bouroumeau-Fuseau

Main server script.
Usage: coffee server.coffee [path/to/manifest.json, [path/to/other/manifest.json, ...]]

Available options:

    --readonly  Disables the import feature from the web interface
    --many      The server.coffee args should be directories containing subfolders with manifest.json files
    --watch     Watch files for modifications and automatically reload them
    --title     Title in the web interface

###

express = require 'express'
less = require 'less'
eco = require 'eco'
fs = require 'fs'
path = require 'path'
ManifestStorage = require './app/storage'

app = express.createServer()

#------------------------------------------------------------------------------
# CONFIGURATION

app.configure ->
    app.use express.logger()
    app.use express.bodyParser()
    app.use express.cookieParser()
    app.use express.compiler({
        src: __dirname + '/app/assets', 
        dest: __dirname + '/public',
        enable: ['less', 'coffeescript'] })
    app.use express.static(__dirname + '/public')
    
    app.set 'view engine', 'html'
    app.set 'views', './app/views'
    app.set 'view options', layout: false
    app.register '.html', 
        compile: (str, options) ->
            return (locals) ->
                eco.render str, locals

app.configure 'development', ->
    app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', ->
    app.use express.errorHandler()

#------------------------------------------------------------------------------
# CORE

session = 
    store: null
    search: null
    argv: []
    options: {
        title: 'Beautiful Docs'
        readonly: false
        watch: false
        many: false
        search: false
        embedly: false
    }

for arg in process.argv.slice(2)
    if arg.substr(0, 2) == '--'
        parts = arg.split '='
        session.options[parts[0].substr(2).replace('-', '_')] = parts[1] || true
    else
        session.argv.push arg

if session.options.search
    Search = require('./app/search').Search
    host = if typeof(session.options.search) is 'string' then session.options.search else 'localhost'
    console.log "Activating search server ('#{host}')"
    session.search = new Search(host)
session.store = new ManifestStorage(session.options, session.search)

#
# Loads manifest files specified in filesToLoad
#
# @param array filesToLoad
# @param bool watch
# @param function callback
#
loadFiles = (filesToLoad, watch=true, callback=null) ->
    nbFilesToLoad = filesToLoad.length
    for file in filesToLoad
        if path.existsSync(file)
            session.store.load fs.realpathSync(file), (manifest) -> 
                if watch
                    console.log "Watching file '" + manifest.filename + "' for changes"
                    manifest.watch()
                if --nbFilesToLoad == 0 and callback then callback()

#
# Returns a list of manifests from a list of directories
#
# Manifests will be searched in subfolders of the specified directories
#
# @param array dirs
#
listManifestsFromDirs = (dirs) ->
    filesToLoad = []
    for dir in dirs
        for file in fs.readdirSync(dir)
            pathname = path.join(dir, file, 'manifest.json')
            if path.existsSync(pathname)
                filesToLoad.push pathname
    return filesToLoad

#
# Watch a list of directories for new manifests ala listManifestsFromDirs
#
# @param array dirs
#
watchDirsForNewManifests = (dirs) ->
    for dir in dirs
        fs.watch dir, (event, filename) ->
            if event == 'rename'
                pathname = path.join(dir, filename, 'manifest.json')
                if path.existsSync(pathname)
                    console.log "New manifest detected in '" + pathname + "'"
                    loadFiles [pathname]

#
# Starts the http server
#
startServer = ->
    require('./app/actions')(app, session)
    port = session.options.port || 8080
    console.log 'Starting server on port ' + port
    app.listen port


#------------------------------------------------------------------------------
# START

if session.argv.length > 0
    filesToLoad = session.argv
    if session.options.many
        filesToLoad = listManifestsFromDirs session.argv
        watchDirsForNewManifests if session.options.watch

    loadFiles filesToLoad, session.options.watch, startServer

else
    startServer()

