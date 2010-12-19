// this is for easier combining of objects
// but it might interfere with other (foreign) code
// TODO replace with something less obstrusive
Object.prototype.apply = function(values) {
	for (var key in values) {
		this[key] = values[key];
	}
	return this;
};

Memcache = function(host, port){
	this.host = host ? host : 'localhost';
	this.port = port ? port : 11211;
};

Memcache.Connection = require('./connection');
Memcache.Pool = require('./pool');

Memcache.pooling = true;

Memcache.prototype.getConnection = function(){
	if (!this.connection) {
		this.connection = new Memcache.Connection(this.host, this.port);
	}
	return this.connection;
	return this.getPool().getConnection();
};

Memcache.prototype.processRequest = function(request){
	if (Memcache.pooling) {
		return this.getPool().processRequest(request);
	} else {
		return this.getConnection().processRequest(request);
	}
};

Memcache.prototype.getPool = function(){
	if (!this.pool) {
		this.pool = new Memcache.Pool({
			host:this.host,
			port:this.port
		});
	}
	return this.pool;
};

Memcache.prototype.get = function(key, callback){
	var request = {
			command:'get ' + key
	};
	if (callback) request.callback = callback;
	this.processRequest(request);
};

Memcache.prototype.set = function(key, value, options){
	options = {
		expires:0,
		flags:0
	}.apply(options);
	var request = {
		command:'set ' + key + ' ' + options.flags + ' ' + options.expires + ' ' + value.length,
		data:value
	};
	if (options.callback) request.callback = options.callback;
	this.processRequest(request);
};

Memcache.prototype.add = function(key, value, options){
	options = {
		expires:0,
		flags:0
	}.apply(options);
	var request = {
		command:'add ' + key + ' ' + options.flags + ' ' + options.expires + ' ' + value.length,
		data:value
	};
	if (options.callback) request.callback = options.callback;
	this.processRequest(request);
};

Memcache.prototype.append = function(key, value, options){
	options = {}.apply(options);
	var request = {
		command:'append ' + key + ' 0 0 ' + value.length,
		data:value
	};
	if (options.callback) request.callback = options.callback;
	this.processRequest(request);
};

Memcache.prototype.prepend = function(key, value, options){
	options = {}.apply(options);
	var request = {
		command:'prepend ' + key + ' 0 0 ' + value.length,
		data:value
	};
	if (options.callback) request.callback = options.callback;
	this.processRequest(request);
};

Memcache.prototype.del = function(key, options){
	options = {}.apply(options);
	var request = {
		command:'delete ' + key
	};
	if (options.callback) request.callback = options.callback;
	this.processRequest(request);
};

Memcache.prototype.shutdown = function(){
	if (this.connection) this.connection.close();
};

module.exports = Memcache;
