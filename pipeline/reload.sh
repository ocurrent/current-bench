#!/bin/bash
set -eu

cd /mnt/project

. /mnt/environments/development.env

# We run `dune exec dev/jwt.exe` outside the `github-app.sh` script to avoid
# running into issues with the `_build/.lock` being held by the main dune exec
# command being run in the watch mode.
JWT=$(dune exec --root=. --display=quiet dev/jwt.exe "$OCAML_BENCH_GITHUB_APP_ID" "/mnt/environments/$OCAML_BENCH_GITHUB_PRIVATE_KEY_FILE")

export JWT

./dev/github-app.sh &

dune exec --watch bin/main.exe -- "$@"
