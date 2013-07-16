eco = require 'eco'
path = require 'path'
fs = require 'fs'
util = require 'util'
_ = require 'underscore'
less = require 'less'
coffee = require 'coffee-script'
async = require 'async'
S = require 'string'
yaml = require 'js-yaml'

class Generator
    # Generates the html files
    #
    # options - An object with options for the generation and the templates
    constructor: (options) ->
        @options = _.extend({
            theme: 'default',
            compileThemeFiles: true,
            templates: {layout: '_layout.html', page: '_page.html', manifests: '_manifests.html'},
            defaultCategory: "All projects",
            baseUrl: '/'
        }, options)
        @options.baseUrl = S(@options.baseUrl).ensureRight('/')

    # Public: Returns the pathname of a file inside the theme folder
    # 
    # filename   - Filename of the file
    # callback
    getThemeFilename: (filename, callback) ->
        fs.exists @options.theme, (exists) =>
            if exists
                filename = path.join @options.theme, filename
            else
                filename = path.join __dirname, "themes", @options.theme, filename
            fs.exists filename, (exists) -> callback filename, exists

    # Public: Renders a template from a string
    #
    # data      - Template string
    # vars      - An object that will become this in the template
    renderString: (data, vars) ->
        return eco.render data.toString(), _.extend({}, @options, vars)

    fileHasHeader: (filename, callback) ->
        fs.readFile filename, (err, data) ->
            return callback(err) if err
            lines = S(data).lines()
            callback(lines[0] == '---')

    parseFileHeader: (data) ->
        lines = S(data).lines()
        if lines[0] != '---'
            return [false, data]

        lines.shift()
        header = []
        for line in lines
            if line == '---'
                break
            else
                header.push(line)

        data = lines.slice(header.length + 1).join("\n")
        header = if header.length > 0 then yaml.safeLoad(header.join("\n")) else {}
        return [header, data]

    render: (filename, vars, callback) ->
        fs.readFile filename, (err, data) =>
            return callback(err) if err
            [header, data] = @parseFileHeader data
            vars = _.extend({}, vars, header)
            content = @renderString data, vars
            
            if header.layout
                @getThemeFilename header.layout, (tplname, exists) =>
                    if not exists
                        return cb("Missing layout: " + tplname)
                    @render tplname, _.extend({}, vars, {content: content}), callback
            else
                callback(null, content)

    # Public: Equivalent of mkdir -p
    #
    # dir       - Directory to create
    # callback  - A function that will be called once the path is created
    mkdir: (dir, callback) ->
        fs.exists dir, (exists) =>
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
            ins.on 'error', callback
            outs = fs.createWriteStream dest
            outs.on 'error', callback
            ins.on 'end', callback
            ins.pipe outs

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
            name = m.category || @options.defaultCategory
            if not categories[name]
                categories[name] = []
            categories[name].push m

        vars = title: title, categories: categories
        @getThemeFilename '_manifests.html', (tplname, exists) =>
            if not exists
                return callback("Missing template: " + tplname)
            @render tplname, vars, (err, content) =>
                if err
                    callback(err) if callback
                    return
                @mkdir path.dirname(filename), (err) ->
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

        renderFile = (file, filename, cb) =>
            copyAsset = (a, c) => @copy file.makeRelativeUri(a), path.join(destDir, a), c
            vars =  {manifest: manifest, content: file.html}
            @getThemeFilename '_page.html', (tplname, exists) =>
                if not exists
                    return cb("Missing template: " + tplname)
                @render tplname, vars, (err, content) ->
                    return cb(err) if err
                    fs.writeFile path.join(destDir, filename + '.html'), content, (err) ->
                        return cb(err) if err
                        async.forEach file.assets, copyAsset, cb

        renderFiles = (cb) =>
            lock = manifest.files.length
            for i, file of manifest.files
                if manifest.ignoreFirstFileForToc and i == 0 then continue
                allContent += file.html + "\n"
                renderFile file, file.slug, -> cb() if --lock == 0

        renderHomepage = (cb) =>
            renderFile manifest.files[0], 'index', cb

        renderAll = (cb) =>
            @getThemeFilename '_page.html', (tplname, exists) =>
                @render tplname, {manifest: manifest, content: allContent}, (err, content) ->
                    return cb(err) if err
                    fs.writeFile path.join(destDir, 'all.html'), content, cb

        copyStylesheet = (cb) =>
            return cb() if not manifest.options.css?
            filename = manifest.options.css
            if filename.substr(0, 1) != '/' and not filename.match /^(https?):\/\//
                @copy manifest.makeRelativeUri(filename), path.join(destDir, filename), cb
            else
                cb()

        copyThemeFiles = (cb) =>
            @getThemeFilename '.', (srcDir, exists) =>
                return cb() if not exists
                @copyFiles srcDir, destDir, @options.compileThemeFiles, {manifest: manifest}, cb

        async.series([
            ((cb) => @mkdir destDir, cb),
            renderHomepage,
            renderFiles,
            renderAll,
            copyStylesheet,
            copyThemeFiles
        ], (err) -> callback(err) if callback)

    # Public: Copies all files from srcDir to destDir. 
    # Eventually transforms less and coffee files and render html files
    #
    # srcDir                : Where the original assets are located
    # destDir               : Where to copy the assets to
    # compileFiles          : Whether to transform less and coffee files and render html files
    # callback              : A function that will be called once all files are copied
    copyFiles: (srcDir, destDir, compileFiles=true, tplVars={}, callback=null) ->
        compileFile = (data, filename, cb) =>
            if compileFiles and path.extname(filename) == '.less'
                target = path.basename(filename, path.extname(filename)) + '.css'
                less.render data.toString(), (err, css) -> cb(err, target, css)
            else if compileFiles and path.extname(filename) == '.coffee'
                target = path.basename(filename, path.extname(filename)) + '.js'
                cb(null, target, coffee.compile(data.toString()))
            else
                cb(null, filename, data)

        copyFile = (pathname, filename, cb) =>
            fs.readFile pathname, (err, data) =>
                return cb(err) if err
                compileFile data, filename, (err, filename, content) ->
                    return cb(err) if err
                    fs.writeFile path.join(destDir, filename), content, cb

        handleFile = (filename, cb) =>
            pathname = path.join srcDir, filename
            fs.stat pathname, (err, stat) =>
                return cb(err) if err
                if stat.isDirectory()
                    @mkdir path.join(destDir, filename), (err) =>
                        return cb(err) if err
                        @copyFiles pathname, path.join(destDir, filename), compileFiles, tplVars, cb
                else if not S(filename).startsWith('_')
                    @fileHasHeader pathname, (hasHeader) =>
                        if hasHeader
                            @render pathname, tplVars, (err, content) ->
                                compileFile content, filename, (err, filename, content) ->
                                    return cb(err) if err
                                    fs.writeFile path.join(destDir, filename), content, cb
                        else
                            copyFile pathname, filename, cb
                else
                    cb()

        handleFiles = (err, files, cb) =>
            return cb(err) if err
            async.forEach files, handleFile, cb

        async.series([
            ((cb) => @mkdir destDir, cb),
            ((cb) -> fs.readdir srcDir, (err, files) -> handleFiles err, files, cb),
        ], (err) -> callback(err) if callback)


module.exports = Generator
