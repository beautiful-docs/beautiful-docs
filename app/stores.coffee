
Manifest = require('./manifest').Manifest
crypto = require 'crypto'
Memcache = require './memcachejs/memcache'

class MemoryStore
    constructor: (options) ->
        @store = {}
    
    load: (uri, callback) ->
        key = crypto.createHash('md5').update(uri).digest("hex");
        if @store[key]
            callback @store[key], key
            return
        
        manifest = new Manifest(uri)
        manifest.load =>
            @store[key] = manifest
            callback(manifest, key) if callback
    
    get: (key, callback) ->
        callback @store[key], key

class MemcacheStore
    constructor: (options) ->
        @connection = new Memcache(options.memcache_host || 'localhost', options.memcache_port || 11211)
        @manifestLifetime = options.memcache_lifetime || 60 * 60 * 24
    
    load: (uri, callback) ->
        key = crypto.createHash('md5').update(uri).digest("hex");
        @get key, (manifest) =>
            if manifest
                return callback(manifest, key)
            
            manifest = new Manifest(uri)
            manifest.load =>
                @connection.set 'manifest:' + key, manifest.serialize(),
                    expires: @manifestLifetime
                    callback: -> callback(manifest, key) if callback
            
    get: (key, callback) ->
        @connection.get 'manifest:' + key, (response) =>
            if response.success and response.data != undefined
                callback Manifest.unserialize(response.data), key
            else
                 callback false, key
        

exports.factory = (name, options) ->
    stores = memory: MemoryStore, memcache: MemcacheStore
    new stores[name](options)

