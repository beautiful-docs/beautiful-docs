fs = require 'fs'

exports.actions = (app, store, options) ->

    middleware = (req, res, next) ->
        res.local 'options', options
        next()

    #
    # Error handler
    #
    app.error (err, req, res, next) ->
        if err.message == 404
            res.render 'error_404'
        else
            next err

    #
    # Homepage
    #
    app.get '/', middleware, (req, res) ->
        store.findAll (manifests) ->
            categories = {}
            for m in manifests
                name = m.category || 'All Projects'
                if not categories[name]
                    categories[name] = []
                categories[name].push m
            
            res.render 'index', categories: categories
    
    #
    # Imports a new manifest which uri is specified as the "uri" parameter
    #
    app.get '/import', middleware, (req, res) ->
        if options.readonly
            res.redirect '/'
            return
            
        uri = req.param 'uri'
        if uri.match /^github:/
            uri = "https://raw.github.com/" + uri.substr(7) + "/master/docs/manifest.json"
        else if not uri.match /^https?:\/\//
            uri = "http://" + uri
        
        store.load uri, (manifest) ->
            res.redirect '/' + manifest.slug
    
    #
    # Handles assets relative to the manifest file
    #
    app.get /^\/([a-zA-Z0-9_\-]+)\/(.+\.(bmp|png|jpg|jpeg|gif|zip|tar|tar.bz2|tar.gz|exe|msi))$/i, middleware, (req, res, next) ->
        projectSlug = req.params[0]
        filename = req.params[1]
        store.find projectSlug, (manifest) ->
            if not manifest
                next(new Error(404))
                return
            pathname = manifest.makeUriAbsolute filename
            console.log pathname
            fs.realpath pathname, (err, resolvedPath) -> res.download resolvedPath
    
    #
    # Displays all manifest's pages on a single HTML page
    #
    app.get /^\/([a-zA-Z0-9_\-]+)\/_all$/, middleware, (req, res, next) ->
        projectSlug = req.params[0]
        store.find projectSlug, (manifest) ->
            if not manifest
                next(new Error(404))
            else
                res.render 'all', manifest: manifest
    
    #
    # Displays a single manifest's page
    #
    # Alternative views can be selected using the "layout" parameter.
    # Available layouts are "view" (default), "content" and "iframe".
    #
    # The base url can also be modified using the "baseurl" parameter
    #
    app.get /^\/([a-zA-Z0-9_\-]+)(\/(.*)|)$/, middleware, (req, res, next) ->
        projectSlug = req.params[0]
        if req.params[1] == ''
            # the urls should always look like /projectslug/ instead of /projectslug
            # because of relative assets
            res.redirect('/' + projectSlug + '/')
            return
        pageSlug = req.params[2]

        res.local 'baseUrl', req.param('baseurl', '/' + projectSlug)
        template = req.param('layout', 'view')
        if not template in ['view', 'content', 'iframe']
            template = 'view'

        store.find projectSlug, (manifest) ->
            next(new Error(404)) if not manifest
            res.local 'manifest', manifest
            if pageSlug
                if not manifest.pages[pageSlug]
                    next new Error(404)
                else
                    res.render template, {body: manifest.pages[pageSlug]}
            else
                res.render template, {body: manifest.home}

