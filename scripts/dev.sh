#!/usr/bin/env bash
# Helper script to run development docker-compose commands easily

# Ensure script is always run from the root of the repository
cd $(dirname $0)/..

docker-compose --project-name="current-bench" \
               --file=./environments/development.docker-compose.yaml \
               --env-file=./environments/development.env \
               "$@"
