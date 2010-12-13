
utils = require './app/utils'
fs = require 'fs'
eco = require 'eco'
Manifest = require('./app/manifest').Manifest

[argv, options] = utils.parse_argv
    manifests: [],
    out: './out/',
    baseUrl: ''

try
    fs.mkdirSync options.out, 0777
catch error

sidebarTemplate = fs.readFileSync __dirname + "/app/views/partials/sidebar.html", "utf-8"

for file in argv
    console.log 'Compiling manifest from ' + file
    manifest = new Manifest(file)
    
    manifest.on 'loaded', =>
        sidebarFilename = options.out + 'sidebar.html'
        console.log 'Writing page ' + sidebarFilename
        fs.writeFileSync sidebarFilename, eco.render(sidebarTemplate, { manifest: manifest, baseUrl: options.baseUrl })
        
        for entry in manifest.tableOfContent
            filename = options.out + 'page-' + entry.index + '.html'
            console.log 'Writing page ' + filename
            fs.writeFileSync(filename, manifest.pages[entry.index])
        
    manifest.load()
