eco = require 'eco'
path = require 'path'
fs = require 'fs'
util = require 'util'
_ = require 'underscore'
less = require 'less'
coffee = require 'coffee-script'
async = require 'async'

class Generator
    # Generates the html files
    #
    # options - An object with options for the generation and the templates
    constructor: (options) ->
        @options = _.extend({
            assetsDir: path.join(__dirname, "assets")
            templatesDir: path.join(__dirname, "templates")
            templates: {layout: 'layout.html', page: 'page.html', index: 'index.html'}
            baseUrl: ''
            noHeader: false,
            noToc: false
        }, options)

    # Public: Renders a template "filename" located in options.templatesDir
    #
    # filename  - Filename of the template
    # vars      - An object that will become this in the template
    # callback  - A function that is called with the rendered html
    render: (filename, vars, callback) ->
        fs.readFile path.join(@options.templatesDir, filename), (err, data) =>
            return callback(err) if err
            html = eco.render data.toString(), _.extend({}, @options, vars)
            callback null, html

    # Public: Equivalent of mkdir -p
    #
    # dir       - Directory to create
    # callback  - A function that will be called once the path is created
    mkdir: (dir, callback) ->
        path.exists dir, (exists) =>
            return callback(null) if exists
            @mkdir path.dirname(dir), (err) -> 
                return callback(err) if err
                fs.mkdir dir, callback

    # Public: Copies a file from src to dest
    #
    # src       - Source filename
    # dest      - Destination filename
    # callback  - A function that will be called once the file is copied
    copy: (src, dest, callback) ->
        @mkdir path.dirname(dest), (err) ->
            return callback(err) if err
            ins = fs.createReadStream src
            outs = fs.createWriteStream dest
            util.pump ins, outs, callback
    
    # Public: Generates an index file containing a list of all manifests
    # ordered by category. Default category is "All Projects"
    #
    # title         - Title of the page
    # manifests     - An array of Manifest objects
    # filename      - The filename of the generated file
    # callback      - A function that will be called once the file is created
    generateIndex: (title, manifests, filename, callback=null) ->
        categories = {}
        for m in manifests
            name = m.category || 'All Projects'
            if not categories[name]
                categories[name] = []
            categories[name].push m
        
        vars = title: title, categories: categories
        @render @options.templates.index, vars, (err, content) ->
            if err
                callback(err) if callback
                return
            fs.writeFile filename, content, callback
    
    # Public: Generates all html files associated to a manifest. Also copies
    # relative assets references in the manifest files
    #
    # manifest  : A Manifest object
    # destDir   : Directory where to save all the generated files
    # callback  : A function that will be called once all files are generated
    generate: (manifest, destDir, callback=null) ->
        allContent = ''

        render = (filename, vars, callback) =>
            @render filename, _.extend({manifest: manifest}, vars), callback

        copyAsset = (filename, cb) =>
            @copy file.makeRelativeUri(a), path.join(destDir, a), cb

        renderFile = (file, filename, cb) =>
            copyAsset = (a, c) => @copy file.makeRelativeUri(a), path.join(destDir, a), c
            render @options.templates.page, {content: file.content}, (err, content) =>
                return cb(err) if err
                render @options.templates.layout, {content: content}, (err, content) ->
                    return cb(err) if err
                    fs.writeFile path.join(destDir, filename + '.html'), content, (err) ->
                        return cb(err) if err
                        async.forEach file.assets, copyAsset, cb

        renderFiles = (cb) ->
            lock = manifest.files.length
            for i, file of manifest.files
                if manifest.ignoreFirstFileForToc and i == 0 then continue
                allContent += file.content + "\n"
                renderFile file, file.slug, -> cb() if --lock == 0

        renderAll = (cb) =>
            content = "<div id='content'>#{allContent}</div>"
            render @options.templates.layout, {content: content}, (err, content) ->
                return cb(err) if err
                fs.writeFile path.join(destDir, 'all.html'), content, cb

        async.series([
            ((cb) => @mkdir destDir, cb),
            ((cb) -> renderFile manifest.files[0], 'index', cb),
            ((cb) -> renderFiles cb),
            ((cb) -> renderAll cb)
        ], (err) -> callback(err) if callback)

    # Public: Copies all files from srcDir to destDir. Eventually transforms less and coffee files.
    #
    # destDir               : Where to copy the assets to
    # srcDir                : Where the original assets are located, default to @options.assetsDir
    # compileLessOrCoffee   : Whether to transform less and coffee files
    # callback              : A function that will be called once all files are copied
    copyAssets: (destDir, srcDir=@options.assetsDir, compileLessOrCoffee=true, callback=null) ->
        if typeof(srcDir) == 'function'
            callback = srcDir
            srcDir = @options.assetsDir

        copyFile = (pathname, filename, cb) =>
            if compileLessOrCoffee and path.extname(filename) == '.less'
                fs.readFile pathname, (err, data) ->
                    return cb(err) if err
                    target = path.join destDir, path.basename(filename, path.extname(filename)) + '.css'
                    less.render data.toString(), (e, css) ->  fs.writeFile target, css, cb
            else if compileLessOrCoffee and path.extname(filename) == '.coffee'
                fs.readFile pathname, (err, data) ->
                    return cb(err) if err
                    target = path.join destDir, path.basename(filename, path.extname(filename)) + '.js'
                    fs.writeFile target, coffee.compile(data.toString()), cb
            else
                @copy pathname, path.join(destDir, filename), cb

        handleFile = (filename, cb) =>
            pathname = path.join srcDir, filename
            fs.stat pathname, (err, stat) =>
                return cb(err) if err
                if stat.isDirectory()
                    @copyAssets path.join(destDir, filename), pathname, compileLessOrCoffee, cb
                else
                    copyFile pathname, filename, cb
        
        handleFiles = (err, files, cb) =>
            return cb(err) if err
            async.forEach files, handleFile, cb

        async.series([
            ((cb) => @mkdir destDir, cb),
            ((cb) -> fs.readdir srcDir, (err, files) -> handleFiles err, files, cb),
        ], (err) -> callback(err) if callback)


module.exports = Generator
