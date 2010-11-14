
exports.actions = (app, store, options) ->

    app.get '/', (req, res) -> Controller.index res
    app.get '/import', (req, res) -> Controller.import res, req.param('uri')
    app.get '/view/:key?', (req, res) -> Controller.view res, req.param('key')
    app.get '/view/:key/page-:page', (req, res) -> Controller.view res, req.param('key'), req.param('page')
    app.get '/iframe/:key?', (req, res) -> Controller.iframe res, req.param('key')
    app.get '/iframe/:key/page-:page', (req, res) -> Controller.iframe res, req.param('key'), req.param('page')

    Controller = 
        index: (res) ->
            if options.readonly and options.manifests.length == 1
                res.redirect '/view'
            else
                res.render 'index', locals:
                    options: options
                    
        import: (res, uri) ->
            if uri.match /^github:/
                uri = "https://github.com/" + uri.substr(7) + "/docs/manifest.json"
            else if not uri.match /^https?:\/\//
                uri = "http://" + uri
            
            console.log "Loading manifest from " + uri
            store.create uri, (manifest) ->
                res.redirect '/view/' + manifest.key
        
        view: (res, key, page, template) ->
            template = template || 'view'
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
            else
                res.render template, locals:
                    manifest: manifest
                    body: manifest.home
                    
        iframe: (res, key, page) ->
            Controller.view res, key, page, 'iframe'
        
    
