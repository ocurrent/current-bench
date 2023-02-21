#!/bin/sh
# DO NOT RUN THIS SCRIPT DIRECTLY ON YOUR MACHINE (not inside a docker)
# latest git version adds a 'safe.directory' check that breaks everything.
# we remove this check globally, which would be very dangerous outside a docker environment.

if [ -d /app/local-test-repo ]; then
  cd /app/local-test-repo
  git config --global --add safe.directory '*'
  git daemon --verbose --export-all --base-path=.git --reuseaddr --strict-paths .git/ &
fi

cd /app

# wait for the cluster to generate the file
until [ -f /app/capnp-secrets/admin.cap ]
do
     sleep 1
done

USER=current-bench-pipeline

# submission.cap is used to submit jobs to the workers
/app/bin/ocluster-admin --connect /app/capnp-secrets/admin.cap remove-client "$USER"
/app/bin/ocluster-admin --connect /app/capnp-secrets/admin.cap add-client "$USER" > /app/submission.cap

# give permission to workers
chmod -R a+rw /app/capnp-secrets

# Run migrations
set -eu
echo "Running migrations..."
omigrate up --verbose --source=/app/db/migrations --database="postgresql://docker:docker@db:5432/${OCAML_BENCH_DB_PASSWORD}"

exec "$@"
