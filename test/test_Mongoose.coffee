_           = require "underscore"
async       = require "async"
assert      = require "assert"
config      = require "config"

Connector  = require "../src"


describe "Mongo Change Stream tests Mongoose", ->
	testSchema = null
	connector  = new Connector _.extend {}, config, useMongoose: true
	modelName = "TestChangeStream"

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

			(cb) ->
				connector.mongooseConnection.model modelName, testSchema
				cb()

		], done

	after (done) ->
		connector.stop done

	it "should be possible to create models with connection", ->
		connector.mongooseConnection.model "TestCollection", testSchema

		assert.ok connector.models["TestCollection"], "did not have `TestCollection` model"

	it "should be possible to add documents to db", (done) ->
		connector.mongooseConnection.model "TestModel", testSchema

		(new connector.models.TestModel field1: "what fffss...").save done

	describe "Change Stream Method", ->
		it "should return Changestream cursor", (done) ->
			onChange = ->

			cursor = connector.changeStream { modelName, onChange }

			assert.equal cursor.constructor.name, "ChangeStream"

			cursor.close done

		it "should be possible to create models with connection and receive `insert` changes", (done) ->
			value = "STAY CONNECTED"

			onChange = (change) ->
				assert.equal change.operationType, "insert"
				cursor.close done

			cursor = connector.changeStream { modelName, onChange }

			setImmediate ->
				(new connector.models[modelName] field1: value).save()

		it "should be possible to use pipelines", (done) ->
			value1    = "STAY CONNECTED"
			value2    = "REALLY STAY CONNECTED"
			pipeline = [
				$match:
					$and: [ "fullDocument.field1": $in: [ value1 ] ]
			]

			onChange = (change) ->
				assert.equal change.fullDocument.field1, value1
				cursor.close done

			cursor = connector.changeStream { pipeline, modelName, onChange }

			setImmediate ->
				(new connector.models[modelName] field1: value2).save()

			setImmediate ->
				(new connector.models[modelName] field1: value1).save()

		it "should call onclose if cursor closes", (done) ->
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
			value    = "STAY CONNECTED"

			onChange = (change) ->
				return if change.operationType is "insert"
				assert.equal change.operationType, "delete"
				cursor.close done

			cursor = connector.changeStream { modelName, onChange }

			item = new connector.models[modelName] field1: value

			setImmediate ->
				item.save (error) ->
					return done error if error

					item.remove (error) ->
						return done error if error

		###########################################
		# This test don't work yet because change somehow always contains fullDocument
		#############################

		# it "should be possible to use options (fullDocument)", (done) ->
		# 	value    = "STAY CONNECTED"
		# 	options  = fullDocument: "default"

		# 	onChange = (change) ->
		# 		assert.ok not change.fullDocument
		# 		cursor.close done

		# 	cursor = connector.changeStream { options, modelName, onChange }

		# 	setImmediate ->
		# 		(new connector.models[modelName] field1: value).save()
