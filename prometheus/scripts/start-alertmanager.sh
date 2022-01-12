#!/bin/sh
# Script to start alertmanager.
set -eu

# Alertmanager doesn't provide a way to replace config variables, and we need
# to write our own script to do this. See
# https://github.com/prometheus/alertmanager/issues/504

sed "s|\$ALERTMANAGER_SLACK_API_URL|$ALERTMANAGER_SLACK_API_URL|g" /config/alertmanager.yml > /tmp/alertmanager.yml  # Permissions to write to the same file is a problem, so we write a /tmp file
alertmanager --config.file=/tmp/alertmanager.yml --log.level=debug --web.external-url=https://autumn.ocamllabs.io/_alertmanager/
