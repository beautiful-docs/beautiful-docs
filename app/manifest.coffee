
events = require 'events'
fs = require 'fs'
path = require 'path'
url = require 'url'
http = require 'http'
crypto = require 'crypto'
md = require('node-markdown').Markdown

class Manifest extends events.EventEmitter
    constructor: (filename) ->
        @filename = filename
        @reset()
        
    reset: ->
        @title = 'Documentation'
        @home = ''
        @pages = []
        @files = []
        @tableOfContent = []
        @css = false
        @loaded = false
        
    reload: (callback) ->
        @load @filename, callback
        
    load: (filename, callback) ->
        if typeof(filename) == 'function'
            callback = filename
            filename = false
        @reset()
        @filename = filename || @filename
        @readUri @filename, (data) =>
            manifest = JSON.parse(data)
            @title = manifest.title || ''
            @key = @title.toLowerCase().replace(' ', '')
            @css = manifest.css || false
            
            files = manifest.files || []
            files.unshift manifest.home
            loaded_files = files.length
                
            for j in [0...files.length]
                do =>
                    i = j
                    @readUri @makeUriAbsolute(files[i], @filename), (data) =>
                        if i == 0
                            @home = md(data)
                        else
                            @files[i] = files[i]
                            @pages[i] = md(data)
                            
                        if --loaded_files == 0
                            @buildTableOfCOntent()
                            @loaded = true
                            callback() if callback
                            @emit 'loaded'
                        
    readUri: (uri, callback) ->
        if uri.match /^https?:\/\//
            urlInfo = url.parse uri
            port = urlInfo.port || if urlInfo.protocol == 'http:' then 80 else 443
            reqPath = urlInfo.pathname
            reqPath += urlInfo.search if urlInfo.search
            
            if urlInfo.protocol == 'https:'
                creds = crypto.createCredentials({});
                client = http.createClient port, urlInfo.hostname, true, creds
            else
                client = http.createClient port, urlInfo.hostname
                
            request = client.request 'GET', reqPath, host: urlInfo.hostname
            request.on 'response', (response) ->
                data = ''
                response.on 'data', (chunk) -> data += chunk
                response.on 'end', -> callback data
            if request.end
                request.end()
            else
                request.close()
        else
            fs.readFile uri, (err, data) ->
                if err then throw err
                callback data.toString()
                
    makeUriAbsolute: (uri, root) ->
        if uri.match /^(https?:\/\/|\/)/
            uri
        else if root.match /^https?:\/\//
            urlInfo = url.parse root
            urlInfo.pathname = path.join path.dirname(urlInfo.pathname), uri
            url.format urlInfo
        else
            path.join path.dirname(root), uri
            
    buildTableOfCOntent: ->
        @tableOfContent = []
        for i in [1...@files.length]
            hTags = @pages[i].match /<h([1-6])>.+<\/h\1>/gi
            currentLevel = 1
            scope = @tableOfContent
            for hTag in hTags || []
                level = parseInt hTag.substr(2, 1)
                if level > 2 then continue
                title = hTag.substring hTag.indexOf('>') + 1, hTag.lastIndexOf('<')
                anchor = title.toLowerCase().replace ' ', '-'
                entry = 
                    index: i
                    filename: @files[i]
                    title: title
                    anchor: anchor
                    childs: []
                    
                @pages[i] = @pages[i].replace hTag, '<a name="' + anchor + '"></a>' + hTag
                
                scope = @tableOfContent if level < currentLevel
                scope.push entry
                scope = entry.childs if level == 1
                currentLevel = level
                
    serialize: ->
        JSON.stringify
            filename: @filename
            title: @title
            home: @home
            pages: @pages
            files: @files
            tableOfContent: @tableOfContent
            css: @css
        
Manifest.unserialize = (str, reloadIfExpiredAfter) ->
    data = JSON.parse(str)
    manifest = new Manifest(data.filename)
    manifest.title = data.title
    manifest.home = data.home
    manifest.pages = data.pages
    manifest.files = data.files
    manifest.tableOfContent = data.tableOfContent
    manifest.css = data.css
    manifest.loaded = true
    return manifest
            
exports.Manifest = Manifest

