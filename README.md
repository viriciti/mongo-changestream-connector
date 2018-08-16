# Mongo Changestream Connector

```npm i mongo-changestream-connector```

### Connect and change streams with Mongoose

- Make sure that mongoose (>= 5) is installed and supply the setting `useMongoose: true` to the `Connector` constructor.
- Now, after using the mongoose connection to instantiate models, you can access all mongoose models with `Connector.models`. The reference to the native MongoDB with `Connector.db` will now not be available anymore.
- Finally, instead of specifying `collectionName` in the `changeStream` method, specify `modelName`.

### Release a new version

1) Run `npm run release-test` to make sure that everything is ready and correct for publication on NPM.
2) If the previous step succeeded, release a new master version with a raised version tag using git flow.
3) Run `npm run release` to finally publish the module on NPM.
