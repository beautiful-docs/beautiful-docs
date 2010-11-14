
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
        @title = 'Documentation'
        @html = {}
        @home = ''
        @files = []
        @tableOfContent = []
        @loaded = false
        
    load: (filename) ->
        @reset()
        @filename = filename || @filename
        @readUri @filename, (data) =>
            manifest = JSON.parse(data)
            @title = manifest.title || ''
            
            files = manifest.files || []
            files.unshift manifest.home
            loaded_files = files.length
                
            for i in [0...files.length]
                @readUri @makeUriAbsolute(files[i], @filename), (data) =>
                    if i == 0
                        @home = md(data)
                    else
                        @files[i - 1] = filename: files[i], data: data
                        @html[files[i]] = md(data)
                        
                    if --loaded_files == 0
                        @buildTableOfCOntent()
                        @loaded = true
                        @emit 'loaded'
                        
    readUri: (uri, callback) ->
        if uri.match /^https?:\/\//
            urlInfo = url.parse uri
            port = if urlInfo.protocol == 'http:' then 80 else 443
            client = http.createClient port, urlInfo.hostname
            url = urlInfo.pathname
            url += urlInfo.search if urlInfo.search
            request = client.request 'GET', url, host: urlInfo.hostname
            request.on 'response', (response) =>
                data = ''
                response.on 'data', (chunk) -> data += chunck
                response.on 'en', => callback data
        else
            fs.readFile uri, (err, data) =>
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
        for file in @files
            titles = file.data.match /^#+ (.+)$/gim
            currentLevel = 1
            scope = @tableOfContent
            for title in titles || []
                level = title.indexOf ' '
                title = title.substr(title.indexOf(' ') + 1)
                entry = filename: file.filename, title: title, childs: []
                
                scope = @tableOfContent if level < currentLevel
                scope.push entry
                scope = entry.childs if level == 1
                currentLevel = level
        
            
exports.Manifest = Manifest
