#!/bin/bash
set -eu

cd /mnt/project

./dev/github-app.sh

dune exec --watch bin/main.exe -- "$@"
