
Manifest = require './src/manifest'
Generator = require './src/generator'
async = require 'async'
fs = require 'fs'
path = require 'path'

exports.version = '1.0.0'

exports.Manifest = Manifest
exports.Generator = Generator

# Creates a Manifest object from a JSON-encoded manifest file
#
# filename : The manifest's filename
# callback : A function that will be called with the Manifest object
exports.open = (filename, callback) -> 
    Manifest.load filename, callback

# Creates a Manifest object from a directory containing .md files
#
# dir       : The directory
# callback  : A function that will be called with the Manifest object
exports.createManifestFromDir = (dir, callback) ->
    m = new Manifest({title: path.basename(dir)})
    fs.readdir dir, (err, files) ->
        mdFiles = []
        for f in files
            mdFiles.push path.join(dir, f) if path.extname(f) == '.md'
        m.addFiles mdFiles.sort(), (err) -> callback err, m

# Generates all the html files from a Manifest object
#
# manifest : The Manifest object
# destDir  : Where to save the html files
# options  : An array of options for the generator
# callback : A function that will be called once all files are generated
exports.generate = (manifest, destDir, options={}, callback=null) ->
    g = new Generator(options)
    async.series([
        ((cb) -> g.generate manifest, destDir, cb),
        ((cb) -> g.copyAssets destDir, cb)
    ], (err) -> callback(err) if callback)

# Generates an index file for multiple manifests
#
# title     : The title of the page
# manifests : An array of Manifest object
# filename  : The filename of the index file
# options   : An object of generator options
# callback  : A function that will be called once the index is generated
exports.generateIndex = (title, manifests, filename, options={}, callback=null) ->
    g = new Generator(options)
    g.generateIndex title, manifests, filename, callback

# Creates an HTTP server that will serve files from dir
#
# dir  : The directory where the files to server are located
# port : The port on which the server should listen to, default: 8080
exports.serveStaticDir = (dir, port=8080) ->
    express = require 'express'
    app = express.createServer()
    app.configure =>
        app.use express.static(dir)
        app.use express.errorHandler({ dumpExceptions: true, showStack: true })
    app.listen port
