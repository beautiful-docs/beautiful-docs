var Memcache = {};

Memcache.Request = function(config){
	if (config) this.apply(config);
};

Memcache.Request.prototype.setConnection = function(connection){
	this.connection = connection;
};

Memcache.Request.prototype.parseResponse = function(data){
	if (typeof(data) != 'string') data = data.toString();
	while (data.length > 0) {
		if (!this.dataMode) {
			var index = data.indexOf('\r\n');
			var response = data.substr(0, index);
			var data = data.substr(index + 2, data.length - 2);
			if (response.substring(0, 5) == 'VALUE') {
				this.dataMode = true;
				var split = response.split(' ');
				this.expectedLength = split[3];
			} else if (response == 'END' || response == 'ERROR' || response == 'STORED' || response == 'DELETED' || response == 'NOT_FOUND' || response == 'NOT_STORED') {
				this.finish(response);
			} else {
				// unknown response string
				require('sys').puts(response);
			}
		} else {
			var chunk = data.substr(0, this.expectedLength);
			this.expectedLength -= chunk.length;
			if (this.data) {
				this.data += chunk;
			} else {
				this.data = chunk;
			}
			if (chunk.length < data.length) {
				data = data.substr(chunk.length +2, data.length - chunk.length - 2);
				delete this.dataMode;
			} else {
				data = '';
			}
		}
	}
};

Memcache.Request.prototype.finish = function(status){
	this.success = status != 'ERROR' && status != 'NOT_FOUND' && status != 'NOT_STORED';
	if (this.callback) this.callback(this);
	this.connection.finishRequest(this);
};

module.exports = Memcache.Request;