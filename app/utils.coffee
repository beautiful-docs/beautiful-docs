
exports.parse_argv = (defaults) ->
    argv = []
    options = defaults || {}
    for arg in process.argv
        if arg.substr(0, 2) == '--'
            parts = arg.split '='
            options[parts[0].substr(2)] = parts[1] || true
        else
            argv.push arg
    return [argv, options]
