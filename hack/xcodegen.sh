#!/bin/bash

source ./hack/mint.sh

function generate() {
    if [ ! -f ./environment.xcconfig ]; then
      echo "Not found environment.xcconfig. Create with empty value."
      ./hack/environment-setup.sh --dummy
    fi

    if [ "$CI" = "" ]; then
        export MINT_LINK_PATH="$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH="$MINT_LIBRARY_PATH_AT_INSTALL"
    else
        export MINT_LINK_PATH=".$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH=".$MINT_LIBRARY_PATH_AT_INSTALL"
    fi

    command_output=$(mint which xcodegen 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ]; then
        echo "XcodeGen didn't find. $command_output"
        bootstrap_mint
    fi
    mint run xcodegen generate
}

if [ ${#@} -eq 1 ]; then
    if [ "${@#"-g"}" = "" ] || [ "${@#"--generate"}" = "" ]; then
        generate
    fi
fi
