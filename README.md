# Mongo Changestream Connector

## Description
Connect and change streams with Mongoose


## How to install

This module depends on [mongodb](https://www.npmjs.com/package/mongodb). If you're using Mongoose, and you want to create Mongoose connections instead of native MongoDB connections, e.g. to instantiate your Mongoose models with, [mongoose](https://www.npmjs.com/package/mongoose)@5 is a peer dependency of this module. So, make sure that Mongoose version 5 is installed in your project.

```sh
npm i mongo-changestream-connector
```

Or when using yarn:

```sh
yarn add mongo-changestream-connector
```


## How to use

Supply the setting `useMongoose: true` to the `Connector` constructor.

Now, after using the mongoose connection to instantiate models, you can access all mongoose models with `Connector.models`. The reference to the native MongoDB with `Connector.db` will now not be available anymore.

Finally, instead of specifying `collectionName` in the `changeStream` method, specify `modelName`.

### Convenience variables:

#### When using Mongoose
```connector.models```

#### When using MongoDB

[MongoClient](http://mongodb.github.io/node-mongodb-native/3.1/api/MongoClient.html)
connector.mongoClient = client

[Db Instance](http://mongodb.github.io/node-mongodb-native/3.1/api/Db.html) the return value of `mongoClient.db()`
```connector.db```


## How to contribute

### Release

- Run `npm run release-test` to make sure that everything is ready and correct for publication on NPM.
- If the previous step succeeded, release a new master version with a raised version tag following the git flow standard.
- Run `npm run release` to finally publish the module on NPM.


## How to test

Run all the tests once with coverage:

```sh
npm test
```

Run all the tests without coverage and with a watch:

```sh
npm tests
```

Run the MongoDB tests without coverage and with a watch:

```sh
npm test-mongo
```

Run the Mongoose tests without coverage and with a watch:

```sh
npm test-mongoose
```
