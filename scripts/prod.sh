#!/usr/bin/env bash
# Helper script to run production docker-compose commands easily

# Ensure script is always run from the root of the repository
cd $(dirname $0)/..

docker-compose --project-name="current-bench" \
               --file=./environments/production.docker-compose.yaml \
               --env-file=./environments/production.env \
               "$@"
