
exports.actions = (app, store, options) ->

    app.get '/', (req, res) -> Controller.index req, res
    app.get '/import', (req, res) -> Controller.import req, res, req.param('uri')
    app.get '/view/:key?', (req, res) -> Controller.view req, res, req.param('key')
    app.get '/view/:key/page-:page', (req, res) -> Controller.view req, res, req.param('key'), req.param('page')
    app.get '/iframe/:key?', (req, res) -> Controller.iframe req, res, req.param('key')
    app.get '/iframe/:key/page-:page', (req, res) -> Controller.iframe req, res, req.param('key'), req.param('page')
    app.get '/content/:key?', (req, res) -> Controller.content req, res, req.param('key')
    app.get '/content/:key/page-:page', (req, res) -> Controller.content req, res, req.param('key'), req.param('page')

    Controller = 
        index: (req, res) ->
            if options.readonly and options.manifests.length == 1
                res.redirect '/view'
            else
                res.render 'index', locals:
                    options: options
                    
        import: (req, res, uri) ->
            if uri.match /^github:/
                uri = "https://github.com/" + uri.substr(7) + "/docs/manifest.json"
            else if not uri.match /^https?:\/\//
                uri = "http://" + uri
            
            console.log "Loading manifest from " + uri
            store.create uri, (manifest) ->
                res.redirect '/view/' + manifest.key
        
        view: (req, res, key, page, template, baseUrl) ->
            template = template || 'view'
            baseUrl = baseUrl || '/view'
            if not key
                if options.manifests.length == 1
                    manifest = options.manifests[0]
                else
                    res.redirect '/'
                    return
            else
                manifest = store.get key
                if not manifest
                    res.redirect '/'
                    return
            
            if page
                res.render template, locals:
                    manifest: manifest
                    body: manifest.pages[page]
                    baseUrl: baseUrl
            else
                res.render template, locals:
                    manifest: manifest
                    body: manifest.home
                    baseUrl: baseUrl
                    
        iframe: (req, res, key, page) ->
            Controller.view req, res, key, page, 'iframe', '/iframe'
            
        content: (req, res, key, page) ->
            baseUrl = req.param('baseUrl') || '/content'
            Controller.view req, res, key, page, 'content', baseUrl
        
    
