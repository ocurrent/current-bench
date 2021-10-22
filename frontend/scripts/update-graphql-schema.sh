#!/bin/bash
# Script to update the graphql_schema.json file

URL="${VITE_OCAML_BENCH_GRAPHQL_URL/localhost/graphql-engine}"

yarn --silent \
     gq "${URL}" \
     --header "X-Hasura-Admin-Secret: ${HASURA_GRAPHQL_ADMIN_SECRET}" \
     --introspect --format=json > graphql_schema.json
