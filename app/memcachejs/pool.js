var Memcache = {
	Connection:require('./connection')
};

Memcache.Pool = function(options){
	// default settings
	this.apply({
		maxConnections:10,
		host:'localhost',
		port:11211,
		pool:[]
	});
	// user-specified settings
	if (options) this.apply(options);
	// start a queue
	this.queue = [];
};

Memcache.Pool.prototype.getConnection = function(){
	for (var i = 0; i < this.pool.length; i++) {
		if (!this.pool[i].isBusy()) return this.pool[i];
	}
	if (this.pool.length < this.maxConnections) {
		var connection = new Memcache.Connection(this.host, this.port);
		this.addConnection(connection);
		return connection;
	}
	require('sys').puts('unable to open additional connections - max # of connections reached');
	return false;
};

Memcache.Pool.prototype.addConnection = function(connection){
	var method = this;
	connection.addListener('status', function(status) {
		if (status == 'idle') method.processQueue.apply(method, [connection]);
		//require('sys').puts('status is now ' + status);
	});
	connection.addListener('close', function() {
		method.removeConnection(connection);
	});
	this.pool.push(connection);
	//require('sys').puts('# of connections is now: ' + this.pool.length);
};

Memcache.Pool.prototype.removeConnection = function(connection){
	for (var i = 0; i < this.pool.length; i++){
		if (this.pool[i] == connection) {
			this.pool.splice(i, 1);
			//TODO this should be more specific, i.e. include a second parameter
			//connection.removeListener('status');
			//connection.removeListener('close');
		}
	}
	//require('sys').puts('# of connections is now: ' + this.pool.length);
};

Memcache.Pool.prototype.processQueue = function(connection) {
	if (this.queue.length == 0) return;
	if (connection && !connection.isBusy()) {
		connection.processRequest(this.queue.pop());
		return;
	}
	connection = this.getConnection();
	if (connection) connection.processRequest(this.queue.pop());
};

Memcache.Pool.prototype.processRequest = function(request) {
	this.queue.push(request);
	this.processQueue();
};

module.exports = Memcache.Pool;