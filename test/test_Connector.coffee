_           = require "underscore"
assert      = require "assert"

Connector  = require "../src"

connector = new Connector
	database:  "test-mongo-connector"
	hosts: [
			host: "localhost"
			port: 27021
		,
			host: "localhost"
			port: 27022
		,
			host: "localhost"
			port: 27023
	]
	poolSize: 50
	options:
		replicaSet: "rs0"

testSchema = null

describe "Mongo Connector Test", ->
	describe "Start and Stop function", ->
		it "should start and stop for single host and port", (done) ->
			conn = new Connector
				database:  "test-mongo-connector-2"
				host:      "localhost"
				port:       27017

			conn.start (error) ->
				return done error if error

				conn.stop (error) ->
					return done error if error

					done()

	describe "collections and models", ->
		before (done) ->
			connector.start (error) ->
				return done error if error

				{ Schema } = connector.connection.base

				testSchema = new Schema
					field1:  type:   String
					field2:  type: [ String ]
				,
					timestamps: true

				done()

		after (done) ->
			connector.stop done

		it "should be possible to create models with connection and add documents to db", ->
			connector.connection.model "TestModel", testSchema

			(new connector.models.TestModel field1: "what fffss...").save()

		it "should be possible to create models with connection", ->
			modelName = "TestCollection"
			connector.connection.model modelName, testSchema

			assert.ok connector.models[modelName], "did not have `#{modelName}` collection"

		it "should be possible to create models with connection", (done) ->
			modelName = "TestChangeStream"
			connector.connection.model modelName, testSchema

			# With arbitray properties. Could be left out
			id       = "STAY CONNECTED"
			options  = fullDocument: "updateLookup"
			pipeline = [
				$match:
					$and: [ "fullDocument.field1": $in: [ id ] ]
			]

			onError = (error) ->
				console.error "change stream errored", error

			onClose = ->
				console.info "change stream closed"

			onChange = ->
				done()

			cursor = connector.changeStream { pipeline, modelName, options, onChange, onError, onClose }

			assert.equal typeof cursor, "object", "should return cursor object"

			(new connector.models.TestChangeStream field1: id).save()

			return

		it "should call onclose if cursor closes", (done) ->
			modelName = "TestChangeStream2"
			connector.connection.model modelName, testSchema

			# With arbitray properties. Could be left out
			id       = "STAY CONNECTED"
			options  = fullDocument: "updateLookup"
			pipeline = [
				$match:
					$and: [ "fullDocument.field1": $in: [ id ] ]
			]

			onError = (error) ->
				console.error "change stream errored", error

			onClose = ->
				console.info "change stream closed"
				done()

			onChange = ->
				done new Error "CHANGES!?"

			cursor = connector.changeStream { pipeline, modelName, options, onChange, onError, onClose }
			cursor.close()
