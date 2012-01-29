
# Beautiful docs

Beautiful docs is a documentation viewer based on markdown files.  
Documentation manuals can be described in a manifest file using JSON.

Features:

 - [Markdown syntax](http://daringfireball.net/projects/markdown/syntax) (with support for [Github Flavored Markdown](http://github.github.com/github-flavored-markdown/))
 - Uses files (store them anywhere, in git for example)
 - Automatically generate the table of content
 - Clean and simple to use interface
 - Supports local and remote manifests
 - Stylesheet for printing
 - Supports [embedly](http://embed.ly/)
 - Easy to customize (eg.: for organizations)
 - Support for multiple manifests with an index page

Requires a recent build of nodejs (tested on 0.6.7).  
Install using npm:

    npm install bfdocs


## Manifests

A manifest file contains a JSON object with the following properties:

 - *title*: Title of the manual (optional, default "Documentation")
 - *files*: An array of files
 - *home*: The file to display as the manual homepage (won't be used when computing the TOC)
 - *category*: Category of the manual (used on the homepage) (optional, default none)
 - *css*: An absolute URL to a CSS stylesheet that will be included in the page
 - *codeHighlightTheme*: The highlightjs theme for code highlighting (http://softwaremaniacs.org/soft/highlight/en/)
 - *embedly*: Activate embedly with the specified api key
    Links to embed must be placed alone in a paragraph.

Files can be absolute URIs or relative to the manifest file.  
Example:

    {
        "title": "Beautiful Docs",
        "files": ["README.md"]
    }

## Usage

    bfdocs path/to/manifest.json [path/to/output/dir]

Available options:

 - *--server*: Activates a web server to browse generated files
 - *--port*: Sets the port of the web server (default is 8080)
 - *--watch*: Watches files for modifications and automatically reload them
