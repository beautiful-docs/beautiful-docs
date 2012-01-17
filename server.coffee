
express = require 'express'
less = require 'less'
eco = require 'eco'
fs = require 'fs'
path = require 'path'
ManifestStorage = require './app/storage'

app = express.createServer()

#-----------------------------------------------------------------
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

#-----------------------------------------------------------------
# CORE

argv = []
options =
    title: 'Beautiful Docs'
    readonly: false
    watch: false
    many: false

for arg in process.argv.slice(2)
    if arg.substr(0, 2) == '--'
        parts = arg.split '='
        options[parts[0].substr(2).replace('-', '_')] = parts[1] || true
    else
        argv.push arg

store = new ManifestStorage(options)

listManifestsFromDirs = (dirs) ->
    filesToLoad = []
    for dir in dirs
        for file in fs.readdirSync(dir)
            pathname = path.join(dir, file, 'manifest.json')
            if path.existsSync(pathname)
                filesToLoad.push pathname
    return filesToLoad

loadFiles = (filesToLoad, watch, callback) ->
    nbFilesToLoad = filesToLoad.length
    for file in filesToLoad
        store.load file, (manifest) -> 
            if watch
                console.log "Watching file " + manifest.filename + " for changes"
                manifest.watch()
            if --nbFilesToLoad == 0 then callback()

startServer = ->
    require('./app/actions').actions app, store, options
    port = options.port || 8080
    console.log 'Starting server on port ' + port
    app.listen port

if argv.length > 0
    filesToLoad = argv
    if options.many
        filesToLoad = listManifestsFromDirs argv
    loadFiles filesToLoad, options.watch, startServer

else
    startServer()

