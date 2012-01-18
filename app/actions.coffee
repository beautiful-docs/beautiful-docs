fs = require 'fs'

module.exports = (app, session) ->

    assets_extensions = 'bmp|png|jpg|jpeg|gif|zip|tar|tar.bz2|tar.gz|exe|msi'
    routes = 
        home: '/'
        import: '/import',
        assets: new RegExp('^\\/([a-zA-Z0-9_\\-]+)\\/(.+\\.(' + assets_extensions + '))$', 'i')
        all: /^\/([a-zA-Z0-9_\-]+)\/_all$/
        search: /^\/([a-zA-Z0-9_\-]+)\/_search$/
        page: /^\/([a-zA-Z0-9_\-]+)(\/(.*)|)$/

    #
    # Adds the "options" variable to all views
    #
    add_global_view_vars = (req, res, next) ->
        res.local 'options', session.options
        next()

    #
    # Finds a manifest using the first req.params
    # The manifest will be available through req.manifest and in views
    #
    # The base url can also be modified using the "baseurl" parameter
    #
    extract_manifest_from_params = (req, res, next) ->
        session.store.find req.params[0], (manifest) ->
            if not manifest
                next new Error(404)
            else
                req.manifest = manifest
                res.local 'manifest', manifest
                res.local 'baseUrl', req.param('baseurl', '/' + req.manifest.slug)
                next()

    # middlewares
    middleware = add_global_view_vars
    middleware_with_manifest = [add_global_view_vars, extract_manifest_from_params]

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
    app.get routes.home, middleware, (req, res) ->
        session.store.findAll (manifests) ->
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
    app.get routes.import, middleware, (req, res) ->
        if session.options.readonly
            res.redirect '/'
            return
            
        uri = req.param 'uri'
        if uri.match /^github:/
            uri = "https://raw.github.com/" + uri.substr(7) + "/master/docs/manifest.json"
        else if not uri.match /^https?:\/\//
            uri = "http://" + uri
        
        session.store.load uri, (manifest) -> res.redirect '/' + manifest.slug + '/'
    
    #
    # Handles assets relative to the manifest file
    #
    app.get routes.assets, middleware_with_manifest, (req, res, next) ->
        pathname = req.manifest.makeUriAbsolute req.params[1]
        fs.realpath pathname, (err, resolvedPath) -> 
            if err
                next new Error(404)
            else
                res.download resolvedPath
    
    #
    # Displays all manifest's pages on a single HTML page
    #
    app.get routes.all, middleware_with_manifest, (req, res, next) ->
        res.render 'all'

    #
    # Search handler
    #
    app.get routes.search, middleware_with_manifest, (req, res, next) ->
        if not session.search
            return next(new Error(404))
        
        q = req.param('q')
        session.search.search req.manifest, q, (hits) ->
            res.render 'view', search: { hits: hits, query: q}
    
    #
    # Displays a single manifest's page
    #
    # Alternative views can be selected using the "layout" parameter.
    # Available layouts are "view" (default), "content" and "iframe".
    #
    app.get routes.page, middleware_with_manifest, (req, res, next) ->
        if req.params[1] == ''
            # the urls should always look like /projectslug/ instead of /projectslug
            # because of relative assets
            return res.redirect('/' + req.manifest.slug + '/')

        pageSlug = req.params[2] || req.manifest.slugs[0]
        template = req.param('layout', 'view')
        if not template in ['view', 'content', 'iframe']
            template = 'view'

        if not req.manifest.pages[pageSlug]
            next new Error(404)
        else
            res.render template, {body: req.manifest.pages[pageSlug]}

