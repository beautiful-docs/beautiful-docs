
class exports.RawRenderer
    render: (source) ->
        return source


class exports.MarkdownRenderer
    render: (source) ->
        marked = require 'marked'
        return marked(source)

