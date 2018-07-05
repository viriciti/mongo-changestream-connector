_               = require "underscore"
debug           = require("debug") "mongo-connector"
mongodbUri      = require "mongodb-uri"
mongoose        = require "mongoose"
{ inspect }     = require "util"

mongoose.Promise = global.Promise


class Connector
	constructor: ({ log, @options, host, port, @hosts, @database, @poolSize, @throwHappy }) ->
		@log = log or (require "@tn-group/log") label: "mongo-connector"

		@hosts    = [ { host, port } ]    if host and port
		@poolSize = 5                     if not @poolSize or @poolSize < 5

		throw new Error "hosts must be provided"       unless Array.isArray @hosts
		throw new Error "database must be provided"    unless typeof @database is "string"

	start: (cb) =>
		uri = mongodbUri.format { @hosts, @database, @options }

		@connection = mongoose.createConnection uri, { @poolSize }

		@connection.once "connected", =>
			@log.info "Mongo-connector connected to: #{uri}. Poolsize is #{@poolSize}"

			logReadyState = (conn, event, error) =>
				mssg  = "Mongo-connector connection `#{event}`"
				mssg += " during readystate #{conn.states[conn.readyState]}. " if conn.states
				mssg += " Error: #{error}"                                     if error

				@log.warn mssg

				throw new Error "Happily throwing: #{mssg}" if @throwHappy and event in [ "error", "close" ]

			_.each [ "close", "error", "reconnected", "disconnected" ], (event) =>
				@connection.on event, logReadyState.bind @, @connection, event

			@models = @connection.models

			cb?()

	changeStream: ({ onChange, modelName, pipeline = [], options = {}, onError, onClose }) =>
		unless typeof modelName is "string"
			throw new Error "Must provide `changeStream` function with a `modelName`"
		unless typeof onChange is "function"
			throw new Error "Must provide `changeStream` function with an `onChange` handler."

		model = @connection.models[modelName]

		throw new Error "Model #{modelName} does not exist." unless model

		_onError = (error) =>
			return onError error if onError
			@log.error "Change stream error for (#{modelName}): #{error}"

		_onClose = =>
			return onClose() if onClose
			@log.error "Change stream closed for (#{modelName})."

		debug "Setup #{modelName} a change stream. Inspect pipeline:", inspect pipeline, depth: 10

		watch = model.watch pipeline, options
			.on "change",  onChange
			.on "error",  _onError
			.on "close",  _onClose

		# this is the native cursor
		watch.driverChangeStream

	stop: (cb) =>
		return cb() unless @connection.readyState is 1

		@connection.removeAllListeners [ "close" ] if @throwHappy

		@connection.close (error) =>
			return cb? error if error

			@log.info "Stopped mongo-connector"

			cb?()

	initReplset: (cb) =>
		@log.warn "Don't init replica set in production!"

		return cb() unless @options.replicaSet

		{ MongoClient } = require "mongodb"

		url = mongodbUri.format { @hosts, @database }

		rsConfig =
			_id : "rs0",
			members: _.map @hosts, (host, i) ->
				_id: i
				host: "#{host.host}:#{host.port}"

		MongoClient.connect url, (error, client) ->
			return cb error if error

			client.db("local").admin().replSetGetStatus (error, status) ->
				return cb()     unless error
				return cb error if error.code isnt 94

				client.db("local").admin().command { replSetInitiate: rsConfig }, (error) ->
					return cb error if error

					setTimeout ->
						cb()
					, 10000

module.exports = Connector
