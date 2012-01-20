http = require 'http'

class Search
    constructor: (@host='localhost', @tenant='bfdocs', @port=9200) ->

    index: (manifest, callback) ->
        c = 1 + manifest.slugs.length
        handler = (res) ->
            if --c == 0 and callback then callback()

        @request 'put', manifest.slug, '_home', {body: manifest.homeData}, handler
        for slug, i in manifest.slugs
            if slug
                @request 'put', manifest.slug, slug, {body: manifest.filesData[i]}, handler

    search: (manifest, query, callback) ->
        q = query: { text: { _all: query } }
        @request 'post', manifest.slug, '_search', q, (res) -> 
            slugs = []
            if res and res.hits
                slugs.push h._id for h in res.hits.hits
            callback slugs


    request: (method, type, path, payload, callback) ->
        options =
            host: @host
            port: @port
            method: method.toUpperCase()
            path: @tenant + '/' + type + '/' + path
        
        req = http.request options, (res) ->
            res.setEncoding 'utf8'
            res.on 'data', (data) -> callback JSON.parse data.toString()

        req.on 'error', (e) ->
            console.log 'ERROR: ' + e.message
            callback false

        req.write JSON.stringify(payload)
        req.end()

module.exports = Search
