
utils = require './app/utils'
fs = require 'fs'
path = require 'path'
eco = require 'eco'
Manifest = require('./app/manifest').Manifest

[argv, options] = utils.parse_argv
    manifests: [],
    out: './out/',
    baseUrl: ''

try
    fs.mkdirSync options.out, 0777
catch error

sidebarTemplate = fs.readFileSync path.join(__dirname, "app/views/partials/sidebar.html"), "utf-8"

for file in argv
    console.log 'Compiling manifest from ' + file
    manifest = new Manifest(file)
    manifest.load =>
        sidebarFilename = path.join options.out, 'sidebar.html'
        console.log 'Writing page ' + sidebarFilename
        fs.writeFileSync sidebarFilename, eco.render(sidebarTemplate, { manifest: manifest, baseUrl: options.baseUrl })
        
        for entry in manifest.tableOfContent
            filename = path.join options.out, 'page-' + entry.index + '.html'
            console.log 'Writing page ' + filename
            fs.writeFileSync(filename, manifest.pages[entry.index])
