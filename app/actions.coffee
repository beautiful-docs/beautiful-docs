fs = require 'fs'

exports.actions = (app, store, options) ->

    middleware = (req, res, next) ->
        res.local 'options', options
        next()
                    
    app.error (err, req, res, next) ->
        if err.message == 404
            res.render 'error_404'
        else
            next err

    app.get '/', middleware, (req, res) ->
        store.findAll (manifests) ->
            categories = {}
            for m in manifests
                name = m.category || 'All Projects'
                if not categories[name]
                    categories[name] = []
                categories[name].push m
            
            res.render 'index', categories: categories
    
    app.get '/import', middleware, (req, res) ->
        if options.readonly
            res.redirect '/'
            return
            
        uri = req.param 'uri'
        if uri.match /^github:/
            uri = "https://github.com/" + uri.substr(7) + "/raw/master/docs/manifest.json"
        else if not uri.match /^https?:\/\//
            uri = "http://" + uri
        
        store.load uri, (manifest) ->
            res.redirect '/' + manifest.slug
    
    app.get /^\/([a-zA-Z0-9_\-]+)\/(.+\.(bmp|png|jpg|jpeg|gif|zip|tar|tar.bz2|tar.gz|exe|msi))$/i, middleware, (req, res, next) ->
        projectSlug = req.params[0]
        filename = req.params[1]
        store.find projectSlug, (manifest) ->
            if not manifest or not manifest.isLocal
                next(new Error(404))
                return
            pathname = manifest.makeUriAbsolute filename
            fs.realpath pathname, (err, resolvedPath) ->
                console.log resolvedPath
                res.download resolvedPath
    
    app.get /^\/([a-zA-Z0-9_\-]+)\/_all$/, middleware, (req, res, next) ->
        projectSlug = req.params[0]
        store.find projectSlug, (manifest) ->
            if not manifest
                next(new Error(404))
            else
                res.render 'all', manifest: manifest
    
    app.get /^\/([a-zA-Z0-9_\-]+)(\/(.*)|)$/, middleware, (req, res, next) ->
        projectSlug = req.params[0]
        pageSlug = req.params[2]

        res.local 'baseUrl', req.param('baseurl', '/view')
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

