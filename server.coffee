
express = require 'express'
less = require 'less'
eco = require 'eco'
stores = require './app/stores'

app = express.createServer()

#-----------------------------------------------------------------
# CONFIGURATION

app.configure ->
    app.use express.logger()
    app.use express.bodyDecoder()
    app.use express.compiler({
        src: __dirname + '/app/assets', 
        dest: __dirname + '/public',
        enable: ['less', 'coffeescript'] })
    app.use express.staticProvider(__dirname + '/public')
    
    app.set 'view engine', 'html'
    app.set 'views', './app/views'
    app.set 'view options', layout: false
    app.register '.html', 
        render: (str, options) ->
            eco.render str, options.locals

app.configure 'development', ->
    app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', ->
    app.use express.errorHandler()

#-----------------------------------------------------------------
# CORE

argv = []
options = 
    title: 'Beautiful Docs'
    manifests: []

for arg in process.argv
    if arg.substr(0, 2) == '--'
        parts = arg.split '='
        options[parts[0].substr(2)] = parts[1] || true
    else
        argv.push arg
    
store = stores.factory options.store || 'memory'

startServer = ->
    require('./app/actions').actions app, store, options
    port = options.port || 8080
    console.log 'Starting server on port ' + port
    app.listen port

if argv.length > 0
    filesToLoad = argv.length
    for file in argv
        console.log 'Loading manifest from ' + file
        store.create file, (manifest) -> 
            options.manifests.push manifest
            if --filesToLoad == 0 then startServer()
else
    startServer()

