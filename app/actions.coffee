
exports.index = (req, res) ->
    if global.manifest.loaded and not req.query.reset
        res.redirect '/viewer'
    else
        res.render 'index'
        
exports.load = (req, res) ->
    global.manifest.on 'loaded', -> res.redirect '/viewer'
    global.manifest.load req.param('manifest')
    
exports.viewer = (req, res) ->
    if not global.manifest.loaded
        res.redirect '/'
    else
        res.render 'viewer', locals:
            title: global.manifest.title
            tableOfContent: global.manifest.tableOfContent
            home: global.manifest.home
            
exports.page = (req, res) ->
    res.send global.manifest.html[req.param('filename')]
