
$ ->
    $('#toc a').click ->
        $('#content').load @href, ->
            $('#content pre code').each (i, el) ->
                hljs.highlightBlock el
        return false
