crypto = require 'crypto'

#
# Stores manifests in memory
#
class Store
    constructor: (@options={}) ->
        @manifests = {}
        if @options.search
            Search = require './search'
            @search = new Search(@options.search)

    store: (manifest, callback) ->
        @manifests[manifest.slug] = manifest
        @search.index manifest if @search
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

module.exports = Store
