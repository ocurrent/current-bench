#!/bin/bash
set -eu

NODE_EXPORTER_VERSION=1.3.1
NODE_EXPORTER_EXE="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter"

download_and_extract () {
    wget -c "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
    tar xvfz "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
}

pushd $(dirname $0)

if [ ! -f ${NODE_EXPORTER_EXE} ]; then
    download_and_extract
fi

${NODE_EXPORTER_EXE} "$@"
