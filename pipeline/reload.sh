#!/bin/bash

COMMAND="${*@Q}"

function run {
  cd /app
  sh -c "$COMMAND" &
}

run

cd /mnt/project
/mnt/project/dev/github-app.sh

while :
do
  cd /mnt/project

  inotifywait -q -q -e CLOSE_WRITE \
    lib/dune lib/*.ml lib/*.mli \
    bin/dune bin/*.ml bin/*.mli

  dune build bin/main.exe \
  && (pkill -f '^/app/bin/current-bench-pipeline' || echo 'Not running?') \
  && sleep 0.1 \
  && cp _build/default/bin/main.exe /app/bin/current-bench-pipeline \
  && run
done
