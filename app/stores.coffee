
Manifest = require('./manifest').Manifest

class MemoryStore
    constructor: ->
        @store = {}
    
    create: (uri, callback) ->
        manifest = new Manifest(uri)
        manifest.on 'loaded', =>
            @store[manifest.key] = manifest
            callback manifest
        manifest.load()
        
    get: (key) ->
        @store[key]

exports.factory = (name) ->
    stores = memory: MemoryStore
    new stores[name]()
