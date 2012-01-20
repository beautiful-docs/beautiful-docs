
express = require 'express'
eco = require 'eco'
fs = require 'fs'

class Server

    constructor: (@store, @options={}) ->
        @app = express.createServer()
        @app.configure =>
            @app.use express.logger()
            @app.use express.bodyParser()
            @app.use express.cookieParser()
            @app.use express.compiler({
                src: __dirname + '/assets', 
                dest: __dirname + '/../public',
                enable: ['less', 'coffeescript'] })
            @app.use express.static(__dirname + '/../public')
            
            @app.set 'view engine', 'html'
            @app.set 'views', __dirname + '/views'
            @app.set 'view options', layout: false
            @app.register '.html', 
                compile: (str, options) ->
                    return (locals) ->
                        eco.render str, locals

        @app.configure 'development', =>
            @app.use express.errorHandler({ dumpExceptions: true, showStack: true })

        @app.configure 'production', =>
            @app.use express.errorHandler()

        # routes
        assets_extensions = 'bmp|png|jpg|jpeg|gif|zip|tar|tar.bz2|tar.gz|exe|msi'
        @routes = 
            home: '/'
            assets: new RegExp('^\\/([a-zA-Z0-9_\\-]+)\\/(.+\\.(' + assets_extensions + '))$', 'i')
            all: /^\/([a-zA-Z0-9_\-]+)\/_all$/
            search: /^\/([a-zA-Z0-9_\-]+)\/_search$/
            page: /^\/([a-zA-Z0-9_\-]+)(\/(.*)|)$/

        # Adds the "options" variable to all views
        add_global_view_vars = (req, res, next) =>
            res.local 'options', @options
            next()

        # Finds a manifest using the first req.params
        # The manifest will be available through req.manifest and in views
        #
        # The base url can also be modified using the "baseurl" parameter
        extract_manifest_from_params = (req, res, next) =>
            @store.find req.params[0], (manifest) ->
                if not manifest
                    next new Error(404)
                else
                    req.manifest = manifest
                    res.local 'manifest', manifest
                    res.local 'baseUrl', req.param('baseurl', '/' + req.manifest.slug)
                    next()

        # middlewares
        @middleware = add_global_view_vars
        @middleware_with_manifest = [add_global_view_vars, extract_manifest_from_params]

        # error handler
        @app.error (err, req, res, next) ->
            if err.message == 404
                res.render 'error_404'
            else
                next err

        @addDefaultActions()

    addRoute: (name, callback) ->
        @app.get @routes[name] or name, @middleware, callback

    addManifestRoute: (name, callback) ->
        @app.get @routes[name] or name, @middleware_with_manifest, callback

    addDefaultActions: ->
        @addRoute 'home', (req, res) =>
            @store.findAll (manifests) ->
                categories = {}
                for m in manifests
                    name = m.category || 'All Projects'
                    if not categories[name]
                        categories[name] = []
                    categories[name].push m
                
                res.render 'index', categories: categories
        
        @addManifestRoute 'assets', (req, res, next) ->
            pathname = req.manifest.makeUriAbsolute req.params[1]
            fs.realpath pathname, (err, resolvedPath) -> 
                if err
                    next new Error(404)
                else
                    res.download resolvedPath
        
        @addManifestRoute 'all', (req, res, next) ->
            res.render 'all'

        @addManifestRoute 'search', (req, res, next) ->
            q = req.param('q')
            @store.search req.manifest, q, (hits) ->
                res.render 'view', search: { hits: hits, query: q}
        
        @addManifestRoute 'page', (req, res, next) ->
            if req.params[1] == ''
                # the urls should always look like /projectslug/ instead of /projectslug
                # because of relative assets
                return res.redirect('/' + req.manifest.slug + '/')

            page_slug = req.params[2] || req.manifest.slugs[0]
            template = req.param('layout', 'view')
            if not template in ['view', 'content', 'iframe']
                template = 'view'

            if not req.manifest.pages[page_slug]
                next new Error(404)
            else
                res.render template, {body: req.manifest.pages[page_slug]}

    start: (port=8080) ->
        console.log 'Starting server on port ' + port
        @app.listen port


module.exports = Server
