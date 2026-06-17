#!/bin/bash

function run() {
    if [ "$CI" = "" ]; then
        export MINT_LINK_PATH="$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH="$MINT_LIBRARY_PATH_AT_INSTALL"
    else
        export MINT_LINK_PATH=".$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH=".$MINT_LIBRARY_PATH_AT_INSTALL"
    fi

    command_output=$(mint which scipio 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ]; then
        echo "Scipio didn't find. $command_output"
        mint install giginet/Scipio
    fi
    mint run scipio create . \
        --support-simulators \
        --enable-library-evolution \
        --overwrite \
        --output XCFrameworks
}

if [ ${#@} -eq 1 ]; then
    if [ "${@#"-r"}" = "" ] || [ "${@#"--run"}" = "" ]; then
        run
    fi
fi
