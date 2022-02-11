#!/bin/sh
sudo git checkout live
docker build -t current-bench-postgres:latest -f pipeline/db/Dockerfile .
docker build -t ocurrent/current-bench-pipeline:live -f pipeline/Dockerfile  .
docker build -t ocurrent/current-bench-frontend:live -f frontend/Dockerfile .
docker push ocurrent/current-bench-pipeline:live
docker push ocurrent/current-bench-frontend:live
cd environments
