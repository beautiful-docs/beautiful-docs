
events = require 'events'
fs = require 'fs'
path = require 'path'
url = require 'url'
http = require 'http'
md = require('node-markdown').Markdown

class Manifest extends events.EventEmitter
    constructor: (filename) ->
        @filename = filename
        @reset()
        
    reset: ->
        @key = ''
        @title = 'Documentation'
        @home = ''
        @pages = []
        @files = []
        @tableOfContent = []
        @css = false
        @loaded = false
        
    load: (filename) ->
        @reset()
        @filename = filename || @filename
        @readUri @filename, (data) =>
            manifest = JSON.parse(data)
            @title = manifest.title || ''
            @key = @title.toLowerCase().replace(' ', '-')
            @css = manifest.css || false
            
            files = manifest.files || []
            files.unshift manifest.home
            loaded_files = files.length
                
            for i in [0...files.length]
                @readUri @makeUriAbsolute(files[i], @filename), (data) =>
                    if i == 0
                        @home = md(data)
                    else
                        @files[i] = files[i]
                        @pages[i] = md(data)
                        
                    if --loaded_files == 0
                        @buildTableOfCOntent()
                        @loaded = true
                        @emit 'loaded'
                        
    readUri: (uri, callback) ->
        if uri.match /^https?:\/\//
            urlInfo = url.parse uri
            port = urlInfo.port || if urlInfo.protocol == 'http:' then 80 else 443
            reqPath = urlInfo.pathname
            reqPath += urlInfo.search if urlInfo.search
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
        for i of @files
            hTags = @pages[i].match /<h([1-6])>.+<\/h\1>/gi
            currentLevel = 1
            scope = @tableOfContent
            for hTag in hTags || []
                level = parseInt hTag.substr(2, 1)
                title = hTag.substring hTag.indexOf('>') + 1, hTag.lastIndexOf('<')
                anchor = title.toLowerCase().replace ' ', '-'
                entry = 
                    index: i
                    filename: @files[i].filename
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
    		title: @title
    		toc: @tableOfContent
    		home: @home
    		html: @html
        
            
exports.Manifest = Manifest
