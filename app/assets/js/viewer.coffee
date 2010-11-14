$ ->
    $('#content pre code').each (i, el) ->
        hljs.highlightBlock el
