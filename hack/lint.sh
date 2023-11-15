#!/bin/bash

source ./hack/mint.sh

function run() {
    if [ "$CI" = "" ]; then
        export MINT_LINK_PATH="$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH="$MINT_LIBRARY_PATH_AT_INSTALL"
    else
        export MINT_LINK_PATH=".$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH=".$MINT_LIBRARY_PATH_AT_INSTALL"
    fi
    
    command_output=$(mint which swiftlint 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ]; then
        echo "SwiftLint didn't find. $command_output"
        bootstrap_mint
    fi
    mint run swiftlint --strict
}

if [ ${#@} -eq 1 ]; then
    if [ "${@#"-r"}" = "" ] || [ "${@#"--run"}" = "" ]; then
        run
    fi
fi