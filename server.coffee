
express = require 'express'
less = require 'less'
eco = require 'eco'
stores = require './app/stores'
utils = require './app/utils'

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

[argv, options] = utils.parse_argv
    title: 'Beautiful Docs'
    manifests: []
    store: 'memory'

store = stores.factory options.store, options

startServer = ->
    require('./app/actions').actions app, store, options
    port = options.port || 8080
    console.log 'Starting server on port ' + port
    app.listen port

if argv.length > 0
    filesToLoad = argv.length
    for file in argv
        console.log 'Loading manifest from ' + file
        store.load file, (manifest, key) -> 
            options.manifests.push [key, manifest.title]
            if --filesToLoad == 0 then startServer()
else
    startServer()

