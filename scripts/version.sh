#!/usr/bin/env bash
# Set version environment variable

# Ensure script is always run from the root of the repository
cd $(dirname $0)/..

VERSION=$(git rev-parse HEAD)
ENV_VAR="CURRENT_BENCH_VERSION="
ENV_LINE="${ENV_VAR}${VERSION}"

add_version () {
    test -f $1 && \
        (grep -q "${ENV_VAR}" $1 &&
             sed -i -e "s/${ENV_VAR}.*/${ENV_LINE}/" $1 || echo -e "\n${ENV_LINE}" >> $1) && \
         echo "Updated ${1}"

}

add_version environments/development.env || echo "No development.env file"
add_version environments/production.env || echo "No production.env file"
