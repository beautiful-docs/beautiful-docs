
#
# Markdown renderer
#
class exports.MarkdownRenderer
    render: (source) ->
        marked = require 'marked'
        return marked(source)

