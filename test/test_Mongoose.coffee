_           = require "underscore"
async       = require "async"
assert      = require "assert"
config      = require "config"

Connector  = require "../src"


describe "Mongoose tests", ->
	testSchema = null
	connector  = new Connector _.extend {}, config, useMongoose: true

	before (done) ->
		async.series [
			(cb) ->
				connector.initReplset cb

			(cb) ->
				connector.start (error) ->
					return cb error if error

					{ Schema } = connector.mongooseConnection.base

					testSchema = new Schema
						field1:  type:   String
						field2:  type: [ String ]
					,
						timestamps: true

					cb()
		], done

	after (done) ->
		connector.stop done

	it "should be possible to create models with connection", ->
		modelName = "TestCollection"
		connector.mongooseConnection.model modelName, testSchema

		assert.ok connector.models[modelName], "did not have `#{modelName}` model"

	it "should be possible to add documents to db", ->
		connector.mongooseConnection.model "TestModel", testSchema

		(new connector.models.TestModel field1: "what fffss...").save()

	it "should be possible to create models with connection and recieve `insert` changes", (done) ->
		modelName = "TestChangeStream"
		connector.mongooseConnection.model modelName, testSchema

		# With arbitray properties. Could be left out
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

		cursor = connector.changeStream { pipeline, modelName, onChange, onError, onClose }

		assert.equal typeof cursor, "object", "should return cursor object"

		(new connector.models.TestChangeStream field1: value).save()

		return

	it "should call onclose if cursor closes", (done) ->
		modelName = "TestChangeStream2"
		connector.mongooseConnection.model modelName, testSchema

		onError = (error) ->
			console.error "change stream errored", error

		onClose = ->
			console.info "change stream closed"
			done()

		onChange = ->
			done new Error "CHANGES!?"

		cursor = connector.changeStream { modelName, onChange, onError, onClose }
		cursor.close()

	# Delete changes are based on _id only, not on a field like `identity` `name`.
	it "should recieve `delete` changes", (done) ->
		modelName = "TestChangeStream"
		connector.mongooseConnection.model modelName, testSchema

		# With arbitray properties. Could be left out
		value    = "STAY CONNECTED"
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

		item = new connector.models.TestChangeStream field1: value

		item.save (error) ->
			return done error if error

			item.remove (error) ->
				return done error if error

		return
