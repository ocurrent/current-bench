# OCaml Benchmarks (Frontend)

## Available Scripts

### npm start

Runs the app in the development mode.
Open http://localhost:8080 to view it in the browser.

The page will reload if you make edits.
You will also see any lint errors in the console.

### npm test

Launches the test runner in the interactive watch mode.
See the section about running tests for more information.

### npm run build

Builds a static copy of your site to the `build/` folder.
Your app is ready to be deployed!

**For the best production performance:** Add a build bundler plugin like "@snowpack/plugin-webpack" or "@snowpack/plugin-parcel" to your `snowpack.config.json` config file.

## Updating the GraphQL schema

Make sure that you have [graphqurl](https://github.com/hasura/graphqurl) installed and run:

```
$ gq http://localhost:8080/v1/graphql \
    -H "X-Hasura-Admin-Secret: $REACT_APP_GRAPHQL_KEY" \
    --introspect \
    --format=json \
    > graphql_schema.json
```

Where `$REACT_APP_GRAPHQL_KEY` is the secret key for the GraphQL API.