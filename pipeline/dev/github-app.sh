#!/bin/sh
set -eu
. /mnt/environments/development.env

ngrok authtoken "$OCAML_BENCH_NGROK_AUTH"

ngrok http 8081 --log=stdout > /tmp/ngrok.log &

URL=$(tail -F /tmp/ngrok.log | grep -m 1 -o -E 'https://[^ ]*.ngrok.io$')

WEBHOOK="${URL}/webhooks/github"

SECRET=$(cat "/mnt/environments/$OCAML_BENCH_GITHUB_WEBHOOK_SECRET_FILE")

JWT=$(dune exec --root=. --display=quiet dev/jwt.exe "$OCAML_BENCH_GITHUB_APP_ID" "/mnt/environments/$OCAML_BENCH_GITHUB_PRIVATE_KEY_FILE")

curl \
  -X PATCH \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/app/hook/config \
  -d "{\"url\":\"${WEBHOOK}\",\"secret\":\"${SECRET}\"}"
