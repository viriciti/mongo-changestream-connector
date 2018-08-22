_           = require "underscore"
async       = require "async"
assert      = require "assert"
config      = require "config"

Connector  = require "../src"



describe "Mongo Change Stream tests MongoDB", ->
	connector      = new Connector _.extend {}, config, useMongoose: false
	collectionName = "testchangestreams"
	collection     = null

	before (done) ->
		@timeout 6000

		async.series [
			(cb) ->
				connector.initReplset cb

			(cb) ->
				connector.start cb

			(cb) ->
				collection = connector.db.createCollection collectionName
				cb()

		], done

	after (done) ->
		connector.stop done

	it "should be possible to add documents to db", (done) ->
		coll = connector.db.collection "testdocs"

		coll.insertOne field1: "testValue", done

	describe "Change Stream Method", ->
		it "should return Changestream cursor", (done) ->
			onChange = ->

			cursor = connector.changeStream { collectionName, onChange }

			assert.equal cursor.constructor.name, "ChangeStream"

			cursor.close done

		it "should be possible to receive `insert` changes", (done) ->
			collection = connector.db.collection collectionName
			value      = "STAY CONNECTED"

			onChange = (change) ->
				assert.equal change.operationType, "insert"
				cursor.close done

			cursor = connector.changeStream { collectionName, onChange }

			setImmediate ->
				collection.insertOne { field1: value }, (error, res) ->
					if error
						cursor.close()
						return done error

		it "should call onclose if cursor closes", (done) ->
			collection = connector.db.collection collectionName

			onError = (error) ->
				console.error "change stream errored", error

			onClose = ->
				console.info "change stream closed"
				done()

			onChange = ->
				done new Error "CHANGES!?"

			cursor = connector.changeStream { collectionName, onChange, onError, onClose }
			cursor.close()
