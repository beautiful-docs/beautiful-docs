# Beautiful docs

Beautiful docs is a documentation viewer based on markdown files.  
Documentation manuals can be described in a manifest file using JSON.
It can also generate static pages.

Features:

 - [Markdown syntax](http://daringfireball.net/projects/markdown/syntax) (with support for [Github Flavored Markdown](http://github.github.com/github-flavored-markdown/))
 - The output is fully static and can be hosted on Github or S3
 - Uses files, no database (store them anywhere, in git for example)
 - Automatically generate the table of content
 - Very easy to create your custom theme
 - Generate static pages alongside your documentation (eg: easily create a presentation website for your project)
 - Clean and beautiful default theme with built-in search engine
 - Stylesheet for printing
 - Supports [embedly](http://embed.ly/)
 - Easy to customize (eg.: for organizations)
 - Support for multiple manifests with an index page

Checkout [beautifuldocs.com](http://beautifuldocs.com) for an example or [github](https://github.com/maximebf/beautiful-docs) for the sources.  
You can find a screenshot of the generated doc [here](https://github.com/maximebf/beautiful-docs/raw/master/docs/screenshot.png).

Install using npm:

    npm install beautiful-docs

## Manifests

Manifests are not mandatory but they allow to specify custom options for your documentation.  
A manifest file contains a JSON object with the following properties:

 - *title*: Title of the manual (optional, default "Documentation")
 - *files*: An array of files
 - *links*: An array of links, each item must be a tuple of the form: [title, link]
 - *rootDir*: Root directory where files are located. Relative to the manifest pathname
 - *home*: The file to display as the manual homepage (won't be used when computing the TOC)
 - *css*: Filename or URL of a CSS stylesheet that will be included in the page
 - *category*: Category of the manual (used on the index page) (optional, default none)
 - *maxTocLevel*: Maximum number of levels to display in the table of content (default 2)
 - *makeAssetsRelativeToGithub*: set this option to a github repo name (ie. username/reponame) to make assets urls relative to this repo

Files can be absolute URIs, relative to the rootDir option or relative to the manifest file.
Example:

    {
        "title": "Beautiful Docs",
        "files": ["README.md"]
    }

## Usage

    bfdocs [--option1=value [--option2=value ...]] [/path/to/manifest.json] [/path/to/output/dir]

Available options:

 - *--help* : Display the help information
 - *--server* : Create an HTTP server to access the generated documentation
 - *--port* : The port on which the HTTP server shoud listen
 - *--watch* : Watch files for modifications and reload them automatically
 - *--theme* : Name of bundled theme or path to custom theme
 - *--title* : Title of the index page
 - *--base-url* : Base url of all links
 - *--manifests-only* : Do not treat the last argument as the output dir but also as a manifest
 - *--index-only* : Only generate the index file. The last argument should be the filename of the index
 - *--version* : Display the installed version of beautiful-docs

Default output dir is *./out*.  
You can specify the path to a directory containing markdown files (\*.md) instead of a manifest file

## Default theme

The default theme adds the following options to your manifest.json file:

 - *codeHighlightTheme*: The highlightjs theme for code highlighting (http://softwaremaniacs.org/soft/highlight/en/)
 - *embedly*: Activate embedly with the specified api key. Links to embed must be placed alone in a paragraph.
 - *github*: Repository name on github (user/repo) used to display a "Fork me on Github" banner
 - *googleAnalytics*: Google Analytrics Trackind ID. Adds a Google Analytics Tracking code to the generated website
 - *disqus*: Disqus Shortname. Adds a Disqus comment thread to every documentation page

The theme has a search capability. It will generate a search index at compile time and
you will be able to search your documentation without the need of a server. Everything is done client side!

You can use the following css classes to style your documentation (suround a block with a div tag):

 - *note*: grey box
 - *warning*: orange box
 - *tip*: green box

Tables will be automatically formated.

## Theming and static pages generation

Beautiful Docs makes it very easy for you to create your own theme.
A theme is made of 2 templates:

 - *\_page.html*: used to render each file in the files array. Will receive a `@content` variable with the content of the page
 - *\_manifests.html*: used to render the index page of multiple manifests (optional if you don't plan on using this feature)

A few variables are available inside your templates:

 - `@manifest`: the current `Manifest` object (unless for *_manifests.html* where it is an array of manifests and the variable is named `@manifests`)
 - `@baseUrl`: base url
 - `@title`: the title provided through the command line

The `Manifest` object has some interesting properties:

 - `options`: all the property used in the manifest.json file
 - `maxTocLevel`
 - `title`
 - `slug`: the name of the generated html file without the html extension

Similar to [Jekyll](http://jekyllrb.com), files can have a header enclosed
in *---*. If such a header is found, the file will be rendered using [eco](https://github.com/sstephenson/eco),
Beautiful Docs' rendering engine. The header is a YAML blurbs. All properties
will be available as variables when rendered.

The special *layout* property allows your to wrapped the rendered content
of the current file inside a layout. It must be a filename relative to the
theme path.

Templates have access to the `@include(filename)` function to include files.
The filename must be relative to the current template filename.

All other files in the theme folder are copied over to the output directory.
Less and Coffee files will be automatically converted.
All files starting with an underscore will be ignored.

Example:

    ---
    layout: _layout.html
    ---
    My custom page for <%= @manifest.title %>

Beautiful Docs comes with 2 themes: default and minimal. Have a look at them in the 
*src/themes* folder to learn more about creating your own theme.

## Multiple manifests

Beautiful docs can handle multiple manifests at once and generate and index file to
easily access each of them.

    bfdocs [options] [--manifests-only] /path/to/first/manifest.json /path/to/second/manifest.json /path/to/third/manifest.json [/path/to/output/dir]

If you have more than one manifest and you don't want to specify the output dir, you must use the *--manifests-only* option.

When multiple manifests are specified, each generated ones will be located in its own subfolder.

You can also generate the index file on its own using *--index-only*:

    bfdocs --index-only /path/to/manifest.json /path/to/manifest.json index.html
