Manifest = require('./manifest').Manifest
crypto = require 'crypto'

#
# Stores manifests in memory
#
class ManifestStorage
    constructor: (@options, @search=null) ->
        @manifests = {}
    
    load: (uri, callback) ->
        console.log "Loading manifest from " + uri
        manifest = new Manifest(uri)
        manifest.load =>
            if @manifests[manifest.slug]
                manifest.slug = crypto.createHash('md5').update(uri).digest("hex")
            @manifests[manifest.slug] = manifest
            if @search
                @search.index manifest, ->
            callback(manifest) if callback
        
    find: (slug, callback) ->
        if @manifests[slug]
            callback @manifests[slug]
        else
            callback false

    findAll: (callback) ->
        m = (v for k, v of @manifests)
        callback m

    count: (callback) ->
        callback @manifests.length

module.exports = ManifestStorage
