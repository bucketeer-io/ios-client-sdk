#!/bin/bash

source ./hack/mint.sh

function run() {
    command_output=$(mint which swiftlint 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ]; then
        echo "swiftlint not found. $command_output"
        mint_bootstrap
    fi
    mint run swiftlint --strict
}

if [ ${#@} -eq 1 ]; then
    if [ "${@#"-r"}" = "" ] || [ "${@#"--run"}" = "" ]; then
        run
    fi
fi