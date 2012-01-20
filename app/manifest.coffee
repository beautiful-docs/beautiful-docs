events = require 'events'
fs = require 'fs'
path = require 'path'
url = require 'url'
http = require 'http'
https = require 'https'
crypto = require 'crypto'

#
# Transforms a string to an uri-compatible one
#
# @param string str
#
generateSlug = (str) ->
    str = str.toLowerCase()
    str = str.replace /^\s+|\s+$/g, ""
    str = str.replace /[\/_|\s]+/g, "-"
    str = str.replace /[^a-z0-9-]+/g, ""
    str = str.replace /[-]+/g, "-"
    str = str.replace /^-+|-+$/g, ""

#
# Represents a manifest file
#
# Stores all information from the manifest as well
# as rendered pages and the computed table of content
#
class Manifest extends events.EventEmitter
    constructor: (@renderer) ->
        @reset()
        
    reset: ->
        @title = 'Documentation'
        @slug = 'documentation'
        @category = null
        @files = []
        @filesData = []
        @slugs = []
        @pages = {}
        @tableOfContent = []
        @css = false
        @code_highlight_theme = 'sunburst'
        @loaded = false
        
    reload: (callback) ->
        @load @filename, callback
        
    #
    # Loads a manifest file
    #
    # @param string filename
    # @param function callback
    #
    load: (filename, callback) ->
        @reset()
        if filename.match /^github:/
            filename = "https://raw.github.com/" + filename.substr(7) + "/master/docs/manifest.json"
        @filename = filename
        
        @readUri @filename, (data) =>
            manifest = JSON.parse(data)
            @title = manifest.title || ''
            @slug = generateSlug @title
            @category = manifest.category || null
            @home = manifest.home || null
            @css = manifest.css || null
            @code_highlight_theme = manifest.code_highlight_theme || 'sunburst'
            
            files = manifest.files || []
            files.unshift @home if @home
            loadedFiles = files.length
            for j in [0...files.length]
                do =>
                    i = j
                    @readUri @makeUriAbsolute(files[i]), (data) =>
                        if @home and i == 0
                            @slugs[i] = '_home'
                        else
                            @slugs[i] = generateSlug files[i].substr 0, files[i].lastIndexOf('.')
                        
                        @files[i] = files[i]
                        @filesData[i] = data
                        @pages[@slugs[i]] = @renderPage(data)
                            
                        if --loadedFiles == 0
                            @buildTableOfContent()
                            @loaded = true
                            callback() if callback
                            @emit 'loaded'
    
    #
    # Reads a file from the given uri and calls callback with the data
    #
    # Uri can be an url starting with http:// or https://, or a local filename
    #
    # @param string uri
    # @param function callback
    #
    readUri: (uri, callback) ->
        if not @isLocalFile(uri)
            urlInfo = url.parse uri
            
            options = 
                host: urlInfo.hostname
                port: urlInfo.port || if urlInfo.protocol == 'http:' then 80 else 443
                path: urlInfo.path
                method: 'GET'
                 
            responseHandler = (res) ->
                res.on 'data', (chunk) -> callback chunk.toString()
                res.on 'error', (err) -> throw err
            
            if urlInfo.protocol == 'https:'
                request = https.request options, responseHandler
            else
                request = http.request options, responseHandler
            request.end()
        else
            fs.readFile uri, (err, data) ->
                if err then throw err
                callback data.toString()
                
    #
    # Checks if the uri is a local file or not
    #
    # @param string uri
    # @return bool
    #
    isLocalFile: (uri) ->
        not uri.match /^https?:\/\//
                
    #
    # Makes the uri absolute
    #
    # If uri is a relative uri, it will be resolved relative to the manifests path
    #
    # @param string uri
    # @return string
    #
    makeUriAbsolute: (uri) ->
        if not @isLocalFile(uri) or uri.substr(0, 1) == '/'
            uri
        else if not @isLocalFile(@filename)
            urlInfo = url.parse @filename
            urlInfo.pathname = path.join path.dirname(urlInfo.pathname), uri
            url.format urlInfo
        else
            path.join path.dirname(@filename), uri
            
    #
    # Transforms markdown sources to HTML
    #
    # @param string source
    # @return string
    #
    renderPage: (source) ->
        html = @renderer.render source
        imgs = html.match /<img[^>]*>/gi
        if imgs
            for img in imgs
                src = img.match /src=("|')([^"']+)\1/i
                if src and not @isLocalFile(src[2])
                    url = @makeUriAbsolute src[2]
                    img2 = img.replace src[0], "src=\"#{url}\""
                    html = html.replace img, img2
        return html
            
    #
    # Buils the table of content from titles in the pages
    #
    # Uses <h1> and <h2> tags from the HTML sources
    #
    buildTableOfContent: ->
        @tableOfContent = []
        scope = @tableOfContent
        parentScopes = []
        currentLevel = 0
        maxLevel = 2
        start = if @home then 1 else 0
        for i in [start...@files.length]
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
    
    #
    # Watches the manifest and all the pages files for changes
    #
    watch: ->
        return if @filename.match /^https?:\/\//
        watcher = (curr, prev) => if curr.mtime > prev.mtime then @reload()
        fs.watchFile @filename, watcher
        for i, f of @files
            fs.watchFile @makeUriAbsolute(f), watcher
            
    #
    # Serializes the manifest to a JSON-encoded string
    #
    # @return string
    #    
    serialize: ->
        JSON.stringify
            filename: @filename
            title: @title
            slug: @slug
            pages: @pages
            files: @files
            slugs: @slugs
            tableOfContent: @tableOfContent
            css: @css
        
#
# Builds a manifest object from a JSON-encoded string
#
# @param string str
#
Manifest.unserialize = (str) ->
    data = JSON.parse(str)
    manifest = new Manifest(data.filename)
    manifest.title = data.title
    manifest.slug = data.slug
    manifest.pages = data.pages
    manifest.files = data.files
    manifest.slugs = data.slugs
    manifest.tableOfContent = data.tableOfContent
    manifest.css = data.css
    manifest.loaded = true
    return manifest
            
module.exports = Manifest
