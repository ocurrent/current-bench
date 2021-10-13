#!/bin/bash
# Script to run the vite server and bbs watcher for local development

yarn install

echo "VITE_OCAML_BENCH_GRAPHQL_URL=${VITE_OCAML_BENCH_GRAPHQL_URL}" > /app/.env
echo "VITE_OCAML_BENCH_PIPELINE_URL=${VITE_OCAML_BENCH_PIPELINE_URL}" >> /app/.env

echo "starting watch"
rm -f .bsb.lock  # Remove any watcher locks, if the shutdown was not clean
# NOTE: This is a workaround to avoid the watcher from exiting after compiling,
# instead of watching.  The workaround of redirecting < /dev/zero to the
# watcher is from the GH comment here:
# https://github.com/rescript-lang/rescript-compiler/issues/2750#issuecomment-657402249
yarn watch < /dev/zero &

echo "starting serve"
yarn serve
