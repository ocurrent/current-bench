#!/bin/sh

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

exec "$@"
