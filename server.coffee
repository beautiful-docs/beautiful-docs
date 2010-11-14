
express = require 'express'
less = require 'less'
eco = require 'eco'
Manifest = require('./app/manifest').Manifest

global.manifest = new Manifest();
if process.argv.length > 0
    console.log 'Using manifest: ' + process.argv[0]
    global.manifest.on 'loaded', -> console.log 'Manifest loaded'
    global.manifest.load process.argv[0]

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
# ROUTES

actions = require './app/actions'
app.get '/', actions.index
app.get '/load', actions.load
app.get '/viewer', actions.viewer
app.get '/page', actions.page

#-----------------------------------------------------------------

app.listen(8080);
