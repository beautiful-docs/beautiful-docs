
# Beautiful docs

Beautiful docs is a documentation viewer based on markdown files.  
Documentation manuals are described in a manifest file using JSON.

Features:

 - Markdown syntax
 - Uses files (store them anywhere, in git for example)
 - Automatically generate the table of content
 - Clean and simple to use interface
 - Supports local and remote manifests
 - Stylesheet for printing
 - Easy to customize (eg.: for organizations)

Requires a recent build of nodejs (tested on 0.6.7) and npm.


## Manifests

A manifest file contains a JSON object with the following properties:

 - *home*: The file to display as the manual homepage (won't be used when computing the TOC)
 - *files*: An array of files
 - *title*: Title of the manual (optional, default "Documentation")
 - *category*: Category of the manual (used on the homepage) (optional, default none)
 - *css*: An absolute URL to a CSS stylesheet that will be included in the page

Files can be absolute URIs or relative to the manifest file.  
Example:

    {
        "title": "Beautiful Docs",
        "home": "README.md",
        "files": ["README.md"]
    }

## Usage

    coffee server.coffee [path/to/manifest.json, [path/to/manifest.json, ...]]

Available options:

 -  *--readonly*: Disables the import feature from the web interface
 -  *--many*: The server.coffee args should be directories containing subfolders with manifest.json files
 -  *--watch*: Watch files for modifications and automatically reload them
 -  *--title*: Title in the web interface

## Web interface

![Web interface](https://raw.github.com/maximebf/beautiful-docs/master/docs/screenshot.png)

If --readonly is not used, a form will be presented of the homepage to import manifests.  
Only urls can be used in this form. Manifests located on a *docs/* folder in a github repo
can be quickly added using "github:user/repo".
