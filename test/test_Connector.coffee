_           = require "underscore"
async       = require "async"
assert      = require "assert"
config      = require "config"

Connector  = require "../src"


describe "Mongo Connector Test", ->
	connector  = new Connector config
	testSchema = null

	describe "collections and models", ->
		@timeout 11000

		before (done) ->
			async.series [
				(cb) ->
					connector.initReplset cb

				(cb) ->
					connector.start (error) ->
						return cb error if error

						{ Schema } = connector.connection.base

						testSchema = new Schema
							field1:  type:   String
							field2:  type: [ String ]
						,
							timestamps: true

						cb()
			], done

		after (done) ->
			connector.stop done

		it "should be possible to create models with connection and add documents to db", ->
			connector.connection.model "TestModel", testSchema

			(new connector.models.TestModel field1: "what fffss...").save()

		it "should be possible to create models with connection", ->
			modelName = "TestCollection"
			connector.connection.model modelName, testSchema

			assert.ok connector.models[modelName], "did not have `#{modelName}` collection"

		it "should be possible to create models with connection and recieve `insert` changes", (done) ->
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

			onChange = (change) ->
				assert.equal change.operationType, "insert"
				cursor.close()
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

		# Delete changes are based on _id only, not on a field like `identity` or `chargestation`.
		# Considering the currenct acl of the CS, delete changes can never be queried for.
		# They are thus irrelevant.
		# We leave the test here nonetheless for other use cases.
		it "should recieve `delete` changes", (done) ->
			modelName = "TestChangeStream"
			connector.connection.model modelName, testSchema

			# With arbitray properties. Could be left out
			id       = "STAY CONNECTED"
			options  = fullDocument: "updateLookup"
			pipeline = []

			onError = (error) ->
				console.error "change stream errored", error

			onClose = ->
				console.info "change stream closed"

			onChange = (change) ->
				if change.operationType isnt "insert"
					assert.equal change.operationType, "delete"
					cursor.close()
					done()

			cursor = connector.changeStream { pipeline, modelName, options, onChange, onError, onClose }

			assert.equal typeof cursor, "object", "should return cursor object"

			item = new connector.models.TestChangeStream field1: id

			item.save (error) ->
				return done error if error

				item.remove (error) ->
					return done error if error

			return
