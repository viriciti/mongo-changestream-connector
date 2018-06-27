_               = require "underscore"
debug           = require("debug") "mongo-connector"
mongodbUri      = require "mongodb-uri"
mongoose        = require "mongoose"
{ inspect }     = require "util"

mongoose.Promise = global.Promise


class Connector
	constructor: ({ log, @options, host, port, @hosts, @database, @poolSize }) ->
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

			_.each [ "close", "error", "reconnected", "disconnected" ], (event) =>
				@connection.on event, logReadyState.bind @, @connection, event

			cb?()

	changeStream: ({ onChange, collectionName, pipeline = [], options = {}, stop = -> }) =>
		unless typeof collectionName is "string"
			throw new Error "Must provide `changeStream` function with a `collectionName`"
		unless typeof onChange is "function"
			throw new Error "Must provide `changeStream` function with an `onChange` handler."

		collection = @connection.collections[collectionName]

		debug "Setup #{collectionName} a change stream. Inspect pipeline:", inspect pipeline, depth: 10

		cursor = collection.watch pipeline, options

		cursor
			.on "change", onChange
			.on "error", (error) =>
				@log.error "Change stream error for (#{collectionName}): #{error}"
				throw error

				# instead of throwing we could do this:
				# cursor.close()
				# setTimeout =>
				# 	@changeStream: ({ pipeline, collectionName, onChange, stop }) =>
				# , 1000

			.on "close", =>
				@log.error "Change stream closed for (#{collectionName})."
				stop?()

	stop: (cb) =>
		return cb() unless @connection.readyState is 1

		@connection.close (error) =>
			return cb? error if error

			@log.info "Stopped mongo-connector"

			cb?()

module.exports = Connector
