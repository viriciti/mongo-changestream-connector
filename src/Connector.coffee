_                  = require "underscore"
debug              = require("debug") "mongo-changestream-connector"
mongodbUri         = require "mongodb-uri"
{ inspect }        = require "util"
{ MongoClient }    = require "mongodb"

{ defaultLogger }  = require "./lib"


class Connector
	constructor: (args) ->
		{ log, @options = {}, host, port, @hosts, @database, @throwHappy, @useMongoose } = args

		@log = log or defaultLogger "mongo-changestream-connector"

		@mongo_or_mongoose = if @useMongoose then "Mongoose" else "MongoDB"
		@hosts             = [ { host, port } ] if host and port
		@options.poolSize  = 5                  if not @options.poolSize or @options.poolSize < 5
		@stopping          = false

		throw new Error "hosts must be provided"       unless Array.isArray @hosts
		throw new Error "database must be provided"    unless typeof @database is "string"

		if @useMongoose
			try
				require "mongoose"
			catch error
				throw new Error "Mongoose must be installed!"

	start: (cb) =>
		uri = mongodbUri.format { @hosts, @database, @options }

		if @useMongoose
			mongoose = require "mongoose"

			mongoose.Promise = global.Promise

			@mongooseConnection = mongoose.createConnection uri

			@log.info "Mongoose connecting to: #{uri}."

			return @mongooseConnection.once "connected", =>
				@log.info "Mongoose connected"

				logReadyState = (conn, event, error) =>
					return if @stopping

					mssg  = "mongo-changestream-connector connection `#{event}`"
					mssg += " during readystate #{conn.states[conn.readyState]}. " if conn.states
					mssg += " Error: #{error}"                                     if error

					@log.warn mssg

					throw new Error "Happily throwing: #{mssg}" if @throwHappy and event in [ "error", "close" ]

				_.each [ "close", "error", "reconnected", "disconnected" ], (event) =>
					@mongooseConnection.on event, logReadyState.bind @, @mongooseConnection, event

				@models = @mongooseConnection.models

				cb?()

		@log.info "Mongo connecting to: #{uri}"

		MongoClient.connect uri, (error, client) =>
			return cb? error if error

			@log.info "Mongo connected"

			@mongoClient = client
			@db          = client.db()

			cb?()

	stop: (cb) =>
		@stopping = true

		if @useMongoose
			return cb() unless @mongooseConnection.readyState is 1

			connection = @mongooseConnection
		else
			return cb() unless @mongoClient.isConnected

			connection = @mongoClient

		connection.removeAllListeners [ "close" ] if @throwHappy

		connection.close (error) =>
			return cb? error if error

			@log.info "Stopped Mongo Changestream Connector"
			@stopping = false

			cb?()

	changeStream: (args) =>
		{
			onChange
			model
			streamId
			collection
			pipeline = []
			options = {}
			onError
			onClose
			onEnd
		} = args

		name = if @useMongoose then model else collection

		unless typeof name is "string"
			throw new Error "Must provide `changeStream` function with a
			 `#{if @useMongoose then "model" else "collection"}`"
		unless typeof onChange is "function"
			throw new Error "Must provide `changeStream` function with an `onChange` handler."

		coll =
			if @useMongoose
			then @mongooseConnection.models[name]
			else @db.collection name

		# This can only happen in the case of Mongoose models
		throw new Error "Model #{name} does not exist." unless coll

		_onError = (error) =>
			mssg = "#{@mongo_or_mongoose} Change stream error for `#{name}`."
			mssg += " Connection id: #{streamId}" if streamId
			mssg += error.message

			@log.error mssg
			
			onError error if onError

		# end is called when there is no more data, close is called once when the stream really stops
		_onEnd = =>
			mssg = "#{@mongo_or_mongoose} Change stream for `#{name}` ended."
			mssg += " Connection id: #{streamId}" if streamId
			
			@log.info mssg
			
			onEnd() if onEnd

		_onClose = =>
			mssg = "#{@mongo_or_mongoose} Change stream for `#{name}` closed."
			mssg += " Connection id: #{streamId}" if streamId
			
			@log.info mssg
			
			onClose() if onClose

		debug "Setup a #{@mongo_or_mongoose} change stream for `#{name}`.
		 Inspect pipeline:", inspect pipeline, depth: 10

		watch = coll.watch pipeline, options
			.on "change",  onChange
			.on "error",  _onError
			.on "end",    _onEnd
			.on "close",  _onClose

		return if @useMongoose then watch.driverChangeStream else watch

	initReplset: (cb) =>
		@log.info "Initiating replica set. (don't do this in production!)"

		throw new Error "Need `replicaSet` option" unless @options.replicaSet

		url = mongodbUri.format { @hosts, @database }

		members = _.map @hosts, (host, i) ->
			host: "#{host.host}:#{host.port}"
			_id:   i

		rsConfig =
			_id :    @options.replicaSet
			members: members

		MongoClient.connect url, (error, client) ->
			return cb error if error

			admin = client
				.db "local"
				.admin()

			admin.replSetGetStatus (error, status) ->
				return cb()     unless error
				return cb error if error.code isnt 94

				admin.command replSetInitiate: rsConfig, (error) ->
					return cb error if error

					# Wait for initialisation to be done
					setTimeout ->
						cb()
					, 10000

module.exports = Connector
