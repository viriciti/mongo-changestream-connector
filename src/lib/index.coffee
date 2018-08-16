debug = (require "debug") "mongo-changestream-connector"

debugLogger = {
	info:    debug
	warn:    debug
	error:   debug
	verbose: debug
}

module.exports = { debugLogger }
