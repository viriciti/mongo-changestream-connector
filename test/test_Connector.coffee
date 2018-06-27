_           = require "underscore"
assert      = require "assert"
{ Schema }  = require "mongoose"

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

testSchema = new Schema
	field1:  type:   String
	field2:  type: [ String ]
,
	timestamps: true


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
			connector.start done

		after (done) ->
			connector.stop done

		it "should be possible to create models with connection and add documents to db", ->
			connector.connection.model "TestModel", testSchema

			(new connector.connection.models.TestModel field1: "what fffss...").save()

		it "should be possible to create models with connection", ->
			connector.connection.model "TestCollection", testSchema

			assert.ok connector.connection.collections.testcollections, "did not have `testcollections` collection"

		it "should be possible to create models with connection", (done) ->
			connector.connection.model "TestChangeStream", testSchema

			collectionName = "testchangestreams"

			# With arbitray properties. Could be left out
			id       = "STAY CONNECTED"
			options  = fullDocument: "updateLookup"
			pipeline = [
				$match:
					$and: [ "fullDocument.field1": $in: [ id ] ]
			]

			stop = ->
				console.info "change stream stopped"

			onChange = ->
				done()

			connector.changeStream { pipeline, collectionName, options, onChange, stop }

			(new connector.connection.models.TestChangeStream field1: id).save()

			return
