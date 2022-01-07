#!/usr/bin/env bash
# Script to validate that the environment variables are configured correctly

# Ensure script is always run from the root of the repository
cd $(dirname $0)/..

extract_var () {
    FILE=$1
    VARNAME=$2
    awk -F '=' "/${VARNAME}/ "'{print $2}' "${FILE}"
}

validate_var() {
    VAR=$(extract_var $1 $2)
    echo -n "Validating ${2}: "
    $3 $VAR
}

ERRORS=

is_dir() {
    if [ -d $1 ]; then
        echo "$1 exists"
    else
        echo "${1} is NOT a valid directory"
        ERRORS="yes"
    fi
}

url_with_schema() {
    regex='https?://.*'
    if [[ $1 =~ $regex ]]
    then
        echo "$1 is valid"
    else
        echo "$1 is NOT valid"
        ERRORS="yes"
    fi
}

is_graphql_url() {
    regex='https?://.*/v1/graphql'
    if [[ $1 =~ $regex ]] || [[ $1 == '/_hasura/v1/graphql' ]]
    then
        echo "$1 is valid"
    else
        echo "$1 is NOT a valid GraphQL URL"
        ERRORS="yes"
    fi
}

is_digit_csv() {
    regex='^[0-9](,[0-9])*$'
    if [[ $1 =~ $regex ]]
    then
        echo "$1 is valid"
    else
        echo "$1 is NOT valid. Use comma separated CPU numbers"
        ERRORS="yes"
    fi
}

validations () {
    echo "Validating ${1}..."
    validate_var $1 OCAML_BENCH_LOCAL_REPO is_dir
    validate_var $1 OCAML_BENCH_FRONTEND_URL url_with_schema
    validate_var $1 OCAML_BENCH_PIPELINE_URL url_with_schema
    validate_var $1 OCAML_BENCH_GRAPHQL_URL is_graphql_url
    validate_var $1 OCAML_BENCH_DOCKER_CPU is_digit_csv
}

validate () {
    if [ -f $1 ];
    then
        validations $1
        if [ ! -z "${ERRORS}" ];
        then
            exit 1
        fi
    else
        echo "${1} does not exist. Skipping..."
    fi
}

validate environments/development.env
validate environments/production.env
