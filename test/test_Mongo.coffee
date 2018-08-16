_           = require "underscore"
async       = require "async"
assert      = require "assert"
config      = require "config"

Connector  = require "../src"

collectionName = "testchangestreams"


describe "Mongo tests", ->
	connector  = new Connector _.extend {}, config, useMongoose: false

	before (done) ->
		@timeout 6000

		async.series [
			(cb) ->
				connector.initReplset cb

			(cb) ->
				connector.start cb

			# (cb) ->
			# 	connector.db.createCollection collectionName, (error) ->
			# 		return cb error if error

			# 		setTimeout cb, 5000

		], done

	after (done) ->
		connector.stop done

	it "should be possible to add documents to db", ->
		coll = connector.db.collection "testdocs"

		coll.insertOne field1: "testValue"

	it "should be possible to receive `insert` changes", (done) ->
		coll = connector.db.collection collectionName

		value    = "STAY CONNECTED"
		pipeline = [
			$match:
				$and: [ "fullDocument.field1": $in: [ value ] ]
		]

		onError = (error) ->
			console.error "change stream errored", error

		onClose = ->
			console.info "change stream closed"

		onChange = (change) ->
			assert.equal change.operationType, "insert"
			cursor.close()
			done()

		cursor = connector.changeStream { pipeline, collectionName, onChange, onError, onClose }

		assert.equal typeof cursor, "object", "should return cursor object"

		coll.insert field1: value

		return

	it "should call onclose if cursor closes", (done) ->
		coll           = connector.db.collection collectionName

		onError = (error) ->
			console.error "change stream errored", error

		onClose = ->
			console.info "change stream closed"
			done()

		onChange = ->
			done new Error "CHANGES!?"

		cursor = connector.changeStream { collectionName, onChange, onError, onClose }
		cursor.close()
