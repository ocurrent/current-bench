#!/bin/sh
sudo git checkout live
docker build -t current-bench-postgres:latest -f pipeline/db/Dockerfile .
docker build -t ocurrent/current-bench-pipeline:latest -f pipeline/Dockerfile  .
docker build -t ocurrent/current-bench-frontend:latest -f frontend/Dockerfile .
docker push ocurrent/current-bench-pipeline:latest
docker push ocurrent/current-bench-frontend:latest
cd environments
