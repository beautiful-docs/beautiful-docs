fs = require 'fs'
path = require 'path'
url = require 'url'
marked = require 'marked'
async = require 'async'
_ = require 'underscore'

# Transforms a string to an uri-compatible one
#
# str : The string to transform
generateSlug = (str) ->
    str = str.toLowerCase()
    str = str.replace /^\s+|\s+$/g, ""
    str = str.replace /[\/_|\s]+/g, "-"
    str = str.replace /[^a-z0-9-]+/g, ""
    str = str.replace /[-]+/g, "-"
    str = str.replace /^-+|-+$/g, ""

# Extracts the name of the file without the extension
#
# filename : Extracts only the name (without the extension) of a file
extractNameFromUri = (filename) ->
    path.basename(filename, path.extname(filename))
                
# Makes the uri relative to another one
#
# uri        : A string representing an URI
# relativeTo : The URI to make the first parameter relative to
makeUriRelativeTo = (uri, relativeTo) ->
    if uri.substr(0, 1) == '/'
        uri
    else
        path.join relativeTo, uri


# Represents a file from a manifest
class ManifestFile
    # Public: Creates a ManifestFile object from the specified uri
    #
    # uri       : Location of the file
    # callback  : A function that will be called with the ManifestFile object
    @load: (uri, callback) ->
        f = new ManifestFile(uri)
        f.refresh (err) -> callback err, f

    # Private: Creates a ManifestFile object
    #
    # uri   : URI of the file
    # raw   : Content of the file
    constructor: (@uri) ->
        @slug = generateSlug extractNameFromUri @uri

    # Public: Refreshes the content
    #
    # callback : A function that will be called once done
    refresh: (callback=null) ->
        fs.readFile @uri, (err, data) =>
            if err
                callback(err) if callback
                return
            @raw = data.toString()
            @render()
            callback null

    # Public: Makes an uri relative to the uri for this file
    #
    # uri   : A string
    makeRelativeUri: (uri) ->
        makeUriRelativeTo uri, path.dirname(@uri)

    # Private: Transforms markdown files to html, extracting
    # urls of relative image and adding anchor tags before all <h> tags
    render: ->
        html = marked @raw

        @assets = []
        imgs = html.match /<img[^>]*>/gi
        for img in imgs || []
            src = img.match /src=("|')([^"']+)\1/i
            if src and not src[2].match /^https?:\/\//
                @assets.push src[2]

        hTags = html.match /<h([1-6])>.+<\/h\1>/gi
        for hTag in hTags || []
            title = hTag.substring hTag.indexOf('>') + 1, hTag.lastIndexOf('<')
            anchor = generateSlug title
            html = html.replace hTag, '<a name="' + anchor + '"></a>' + hTag

        @content = html


# Represents a manifest
#
# Stores all information from the manifest as well
# as rendered files and the computed table of content
class Manifest
    # Public: Creates a Manifest object reading the options from the given uri
    #
    # uri       : The URI of a JSON-encoded file with the options
    # callback  : A function that will be called with the Manifest object
    @load: (uri, callback) ->
        m = new Manifest({}, uri)
        m.refresh (err) -> callback err, m

    # Public: Constructor
    #
    # options   : An object with the manifest's options
    # uri       : The URI of the manifest
    constructor: (options={}, @uri=null) -> 
        @files = []
        @setOptions options

    # Public: Sets the options
    #
    # options   : An object with the manifest's options
    setOptions: (options) ->
        @title = options.title ? ''
        @slug = generateSlug @title
        @category = options.category ? null
        @ignoreFirstFileForToc = options.home?
        @maxTocLevel = options.maxToLevel ? 2
        @options = _.extend({}, options)
        
    # Public: Adds files
    # The table of content will be rebuild
    #
    # files     : An array of URIs
    # callback  : A function that will be called once all files are added
    addFiles: (files, callback=null) ->
        lock = files.length
        d = @files.length
        for i in [0...files.length]
            do =>
                j = d + i
                ManifestFile.load @makeRelativeUri(files[i]), (err, f) =>
                    if err 
                        lock = -1
                        callback(err) if callback
                        return
                    @files[j] = f
                    if --lock == 0
                        @buildTableOfContent()
                        callback(null) if callback

    # Private: Builds the table of content from the <h> tags
    buildTableOfContent: ->
        @tableOfContent = []
        scope = @tableOfContent
        parentScopes = []
        currentLevel = 0
        for i, file of @files
            if @ignoreFirstFileForToc and i == '0' then continue
            hTags = file.content.match /<h([1-6])>.+<\/h\1>/gi
            for hTag in hTags || []
                level = parseInt hTag.substr(2, 1)
                title = hTag.substring hTag.indexOf('>') + 1, hTag.lastIndexOf('<')
                anchor = generateSlug title
                
                if level > @maxTocLevel then continue
                if level <= currentLevel
                    parentScopes = parentScopes.slice 0, parentScopes.length - (currentLevel - level)
                    scope = parentScopes.pop()
                    
                entry = 
                    slug: file.slug
                    title: title
                    anchor: anchor
                    childs: []
                    
                scope.push entry
                parentScopes.push scope
                scope = entry.childs
                currentLevel = level

    # Public: Refreshes the manifest options and all files and rebuilds the table of content
    #
    # callback : A function that will be called once done
    refresh: (callback=null) ->
        if @uri
            fs.readFile @uri, (err, data) =>
                return callback(err) if err
                options = JSON.parse(data.toString())
                files = options.files ? []
                files.unshift options.home if options.home
                @files = []
                @setOptions options
                @addFiles files, (err) =>
                    return callback(err) if err
                    @refreshFiles callback
        else
            @refreshFiles callback

    # Public: Refreshes all files and rebuilds the table of content
    #
    # callback : A function that will be called once done
    refreshFiles: (callback=null) ->
        async.forEach @files, ((f, cb) -> f.refresh cb), (err) =>
            if err
                callback(err) if err
                return
            @buildTableOfContent()
            callback(null) if callback

    # Public: Makes an uri relative to this manifest's URI
    #
    # uri : A string representing an URI
    makeRelativeUri: (uri) ->
        return uri if not @uri
        makeUriRelativeTo uri, path.dirname(@uri)
    
    # Watches all the associated files for changes
    #
    # callback : A function that will be called whenever a files changes
    watch: (callback) ->
        watcher = (curr, prev) => @refresh callback if curr.mtime > prev.mtime
        fs.watchFile @uri, watcher if @uri
        fs.watchFile f.uri, watcher for f in @files

            
module.exports = Manifest
