#!/bin/sh
# Script to start prometheus.
set -eu

# Prometheus doesn't provide a way to replace config variables, and we need
# to write our own script to do this. See
# https://github.com/prometheus/prometheus/issues/2357

PROMETHEUS_SCRAPE_TARGETS=$(echo $OCAML_BENCH_CLUSTER_POOLS|sed -E "s|(\w)+|'\0.ocamllabs.io:10080'|g")

sed "s|\$PROMETHEUS_SCRAPE_TARGETS|$PROMETHEUS_SCRAPE_TARGETS|g" /etc/prometheus/prometheus.yml > /tmp/prometheus.yml  # Permissions to write to the same file is a problem, so we write a /tmp file

prometheus --web.enable-lifecycle  --config.file=/tmp/prometheus.yml
