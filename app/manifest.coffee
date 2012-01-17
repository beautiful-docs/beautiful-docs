
events = require 'events'
fs = require 'fs'
path = require 'path'
url = require 'url'
http = require 'http'
https = require 'https'
crypto = require 'crypto'
md = require('node-markdown').Markdown

generateSlug = (str) ->
    str = str.toLowerCase()
    str = str.replace /^\s+|\s+$/g, ""
    str = str.replace /[\/_|\s]+/g, "-"
    str = str.replace /[^a-z0-9-]+/g, ""
    str = str.replace /[-]+/g, "-"
    str = str.replace /^-+|-+$/g, ""

class Manifest extends events.EventEmitter
    constructor: (filename) ->
        @filename = filename
        @reset()
        
    reset: ->
        @title = 'Documentation'
        @slug = 'documentation'
        @category = null
        @home = ''
        @homeFile = false
        @files = []
        @slugs = []
        @pages = {}
        @tableOfContent = []
        @css = false
        @loaded = false
        @isLocal = null
        
    reload: (callback) ->
        @load @filename, callback
        
    load: (filename, callback) ->
        if typeof(filename) == 'function'
            callback = filename
            filename = false
        @reset()
        @filename = filename || @filename
        @isLocal = not @filename.match /^https?:\/\//
        @readUri @filename, (data) =>
            manifest = JSON.parse(data)
            @title = manifest.title || ''
            @slug = generateSlug @title
            @category = manifest.category || null
            @css = manifest.css || false
            
            files = manifest.files || []
            files.unshift manifest.home
            loadedFiles = files.length
            for j in [0...files.length]
                do =>
                    i = j
                    @readUri @makeUriAbsolute(files[i]), (data) =>
                        if i == 0
                            @home = @renderPage(data)
                            @homeFile = files[i]
                        else
                            @files[i] = files[i]
                            @slugs[i] = generateSlug files[i].substr 0, files[i].lastIndexOf('.')
                            @pages[@slugs[i]] = @renderPage(data)
                            
                        if --loadedFiles == 0
                            @buildTableOfContent()
                            @loaded = true
                            callback() if callback
                            @emit 'loaded'
                        
    readUri: (uri, callback) ->
        if uri.match /^https?:\/\//
            urlInfo = url.parse uri
            reqPath = urlInfo.pathname
            reqPath += urlInfo.search if urlInfo.search
            
            options = 
                host: urlInfo.hostname
                port: urlInfo.port || if urlInfo.protocol == 'http:' then 80 else 443
                path: reqPath
                method: 'GET'
                 
            responseHandler = (res) ->
                data = ''
                res.on 'data', (chunk) -> data += chunk
                res.on 'end', -> callback data
            
            if urlInfo.protocol == 'https:'
                request = https.request options, responseHandler
            else
                request = http.request options, responseHandler
            request.end()
        else
            fs.readFile uri, (err, data) ->
                if err then throw err
                callback data.toString()
                
    isLocalFile: (uri) ->
        not uri.match /^https?:\/\//
                
    makeUriAbsolute: (uri) ->
        if not @isLocalFile(uri) or uri.substr(0, 1) == '/'
            uri
        else if @isLocal
            urlInfo = url.parse @filename
            urlInfo.pathname = path.join path.dirname(urlInfo.pathname), uri
            url.format urlInfo
        else
            path.join path.dirname(@filename), uri
            
    renderPage: (source) ->
        html = md source
        imgs = html.match /<img[^>]*>/gi
        if imgs
            for img in imgs
                src = img.match /src=("|')([^"']+)\1/i
                if src and not @isLocalFile(src[2])
                    url = @makeUriAbsolute src[2]
                    img2 = img.replace src[0], "src=\"#{url}\""
                    html = html.replace img, img2
        return html
            
    buildTableOfContent: ->
        @tableOfContent = []
        scope = @tableOfContent
        parentScopes = []
        currentLevel = 0
        maxLevel = 2
        for i in [1...@files.length]
            slug = @slugs[i]
            hTags = @pages[slug].match /<h([1-6])>.+<\/h\1>/gi
            for hTag in hTags || []
                level = parseInt hTag.substr(2, 1)
                title = hTag.substring hTag.indexOf('>') + 1, hTag.lastIndexOf('<')
                anchor = generateSlug title
                @pages[slug] = @pages[slug].replace hTag, '<a name="' + anchor + '"></a>' + hTag
                
                if level > maxLevel then continue
                if level <= currentLevel
                    parentScopes = parentScopes.slice 0, parentScopes.length - (currentLevel - level)
                    scope = parentScopes.pop()
                    
                entry = 
                    index: i
                    filename: @files[i]
                    slug: slug
                    title: title
                    anchor: anchor
                    childs: []
                    
                scope.push entry
                parentScopes.push scope
                scope = entry.childs
                currentLevel = level
                
    watch: ->
        return if @filename.match /^https?:\/\//
        @watchFile @filename
        if @homeFile then @watchFile @homeFile
        for i, f of @files
            @watchFile @makeUriAbsolute(f)
                
    watchFile: (filename) ->
        fs.watchFile filename, (curr, prev) =>
            if curr.mtime > prev.mtime then @reload()
                
    serialize: ->
        JSON.stringify
            filename: @filename
            title: @title
            slug: @slug
            home: @home
            pages: @pages
            files: @files
            slugs: @slugs
            tableOfContent: @tableOfContent
            css: @css
        
Manifest.unserialize = (str, reloadIfExpiredAfter) ->
    data = JSON.parse(str)
    manifest = new Manifest(data.filename)
    manifest.title = data.title
    manifest.slug = data.slug
    manifest.home = data.home
    manifest.pages = data.pages
    manifest.files = data.files
    manifest.slugs = data.slugs
    manifest.tableOfContent = data.tableOfContent
    manifest.css = data.css
    manifest.loaded = true
    return manifest
            
exports.Manifest = Manifest

