_               = require "underscore"
debug           = require("debug") "mongo-changestream-connector"
mongodbUri      = require "mongodb-uri"
{ inspect }     = require "util"

{ debugLogger }      = require "./lib"


class Connector
	constructor: (args) ->
		{ log, @options = {}, host, port, @hosts, @database, @poolSize, @throwHappy, @useMongoose } = args

		@log = log or debugLogger

		@hosts    = [ { host, port } ] if host and port
		@poolSize = 5                  if not @poolSize or @poolSize < 5

		throw new Error "hosts must be provided"       unless Array.isArray @hosts
		throw new Error "database must be provided"    unless typeof @database is "string"

		if @useMongoose
			try
				require "mongoose"
			catch error
				throw new Error "Mongoose must be installed!"

	start: (cb) =>
		if @useMongoose
			mongoose = require "mongoose"

			mongoose.Promise = global.Promise

			uri = mongodbUri.format { @hosts, @database, @options }

			@mongooseConnection = mongoose.createConnection uri, { @poolSize }

			@mongooseConnection.once "connected", =>
				@log.info "Mongoose connection to: #{uri}. Poolsize is #{@poolSize}."

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

		else
			{ MongoClient } = require "mongodb"

			uri = mongodbUri.format { @hosts, @database, @options }

			MongoClient.connect uri, { @poolSize }, (error, client) =>
				return cb? error if error

				@log.info "Mongo connection to: #{uri}. Poolsize is #{@poolSize}."

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
		{ onChange, modelName, collectionName, pipeline = [], options = {}, onError, onClose } = args

		name = if @useMongoose then modelName else collectionName

		unless typeof name is "string"
			throw new Error "Must provide `changeStream` function with a
			 `#{if @useMongoose then "modelName" else "collectionName"}`"
		unless typeof onChange is "function"
			throw new Error "Must provide `changeStream` function with an `onChange` handler."

		collection =
			if @useMongoose
			then @mongooseConnection.models[name]
			else @db.collection name

		# This can only happen in the case of Mongoose models
		throw new Error "Model #{name} does not exist." unless collection

		_onError = (error) =>
			return onError error if onError
			@log.error "Change stream error for (#{name}): #{error}"

		_onClose = =>
			return onClose() if onClose
			@log.error "Change stream closed for (#{name})."

		debug "Setup a change stream for `#{name}`. Inspect pipeline:", inspect pipeline, depth: 10

		watch = collection.watch pipeline, options
			.on "change",  onChange
			.on "error",  _onError
			.on "close",  _onClose

		return if @useMongoose then watch.driverChangeStream else watch

	initReplset: (cb) =>
		@log.warn "Don't init replica set in production!"

		throw new Error "Need `replicaSet` option" unless @options.replicaSet

		{ MongoClient } = require "mongodb"

		url = mongodbUri.format { @hosts, @database }

		members = _.map @hosts, (host, i) ->
			host: "#{host.host}:#{host.port}"
			_id:   i

		rsConfig =
			_id :    @options.replicaSet
			members: members

		MongoClient.connect url, (error, client) ->
			return cb error if error

			client.db("local").admin().replSetGetStatus (error, status) ->
				return cb()     unless error
				return cb error if error.code isnt 94

				client.db("local").admin().command { replSetInitiate: rsConfig }, (error) ->
					return cb error if error

					# Wait for initialisation to be done
					setTimeout ->
						cb()
					, 10000

module.exports = Connector
