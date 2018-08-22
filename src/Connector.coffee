_                  = require "underscore"
debug              = require("debug") "mongo-changestream-connector"
mongodbUri         = require "mongodb-uri"
{ inspect }        = require "util"
{ MongoClient }    = require "mongodb"

{ defaultLogger }  = require "./lib"


class Connector
	constructor: (args) ->
		{ log, @options = {}, host, port, @hosts, @database, @poolSize, @throwHappy, @useMongoose } = args

		@log = log or defaultLogger "mongo-changestream-connector"

		@mongo_or_mongoose = if @useMongoose then "Mongoose" else "MongoDB"
		@hosts             = [ { host, port } ] if host and port
		@options.poolSize  = 5                  if not @options.poolSize or @options.poolSize < 5

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

			return @mongooseConnection.once "connected", =>
				@log.info "Mongoose connection to: #{uri}."

				logReadyState = (conn, event, error) =>
					mssg  = "mongo-changestream-connector connection `#{event}`"
					mssg += " during readystate #{conn.states[conn.readyState]}. " if conn.states
					mssg += " Error: #{error}"                                     if error

					@log.warn mssg

					throw new Error "Happily throwing: #{mssg}" if @throwHappy and event in [ "error", "close" ]

				_.each [ "close", "error", "reconnected", "disconnected" ], (event) =>
					@mongooseConnection.on event, logReadyState.bind @, @mongooseConnection, event

				@models = @mongooseConnection.models

				cb?()

		MongoClient.connect uri, (error, client) =>
			return cb? error if error

			@log.info "Mongo connection to: #{uri}."

			@mongoClient = client
			@db          = client.db()

			cb?()

	stop: (cb) =>
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

			cb?()

	changeStream: (args) =>
		{ onChange, model, collection, pipeline = [], options = {}, onError, onClose } = args

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
			return onError error if onError
			@log.error "#{@mongo_or_mongoose} Change stream error for (#{name}): #{error}"

		_onClose = =>
			return onClose() if onClose
			@log.error "#{@mongo_or_mongoose} Change stream closed for (#{name})."

		debug "Setup a #{@mongo_or_mongoose} change stream for `#{name}`.
		 Inspect pipeline:", inspect pipeline, depth: 10

		watch = coll.watch pipeline, options
			.on "change",  onChange
			.on "error",  _onError
			.on "close",  _onClose

		return if @useMongoose then watch.driverChangeStream else watch

	initReplset: (cb) =>
		@log.warn "Don't init replica set in production!"

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
