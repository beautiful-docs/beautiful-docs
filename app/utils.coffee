
exports.parse_argv = (defaults) ->
    argv = []
    options = defaults || {}
    start = if process.argv.length > 1 and process.argv[1].match(/bin\/coffee$/) then 2 else 1
    for arg in process.argv.slice(start)
        if arg.substr(0, 2) == '--'
            parts = arg.split '='
            options[parts[0].substr(2).replace('-', '_')] = parts[1] || true
        else
            argv.push arg
    return [argv, options]
