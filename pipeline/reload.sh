#!/bin/bash

COMMAND="${*@Q}"

DIR=_build/default/bin
EXE="${DIR}/main.exe"

function run {
  cd /app
  sh -c "$COMMAND" &
  cd /mnt/project
}

run

/mnt/project/dev/github-app.sh

while :
do
  # NOTE:
  # 1. inotifywait exits with a failure status code when main.exe gets deleted
  #    before a rebuild. So, we watch the directory instead, and make sure the
  #    file exists.
  # 2. Also, we sleep for a short while, to ensure the process has been killed
  #    before copying the new executable and trying to run it.
  inotifywait -q -e CLOSE_WRITE "${DIR}" | grep -q main.exe \
  && (pkill -f '^/app/bin/current-bench-pipeline' || echo 'Not running?') \
  && sleep 0.1 \
  && cp "${EXE}" /app/bin/current-bench-pipeline \
  && run
done
