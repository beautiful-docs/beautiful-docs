
express = require 'express'
less = require 'less'
eco = require 'eco'
fs = require 'fs'
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

for arg in process.argv.slice(2)
    if arg.substr(0, 2) == '--'
        parts = arg.split '='
        options[parts[0].substr(2).replace('-', '_')] = parts[1] || true
    else
        argv.push arg

store = new ManifestStorage(options)

startServer = ->
    require('./app/actions').actions app, store, options
    port = options.port || 8080
    console.log 'Starting server on port ' + port
    app.listen port

if argv.length > 0
    filesToLoad = argv.length
    for file in argv
        store.load file, (manifest) -> 
            if options.watch
                console.log "Watching file #{file} for changes"
                manifest.watch()
            if --filesToLoad == 0 then startServer()
else
    startServer()

