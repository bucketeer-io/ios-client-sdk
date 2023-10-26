#!/bin/bash

MINT_LINK_PATH_AT_INSTALL="mint/bin"

function bootstrap_mint() {
    if [ "$CI" = "" ]; then
        PROJECT_DIR=$(xcodebuild -showBuildSettings | grep "PROJECT_DIR = .*" | sed "s/PROJECT_DIR = //g" | sed "s/ //g")
        export MINT_LINK_PATH="$PROJECT_DIR/$MINT_LINK_PATH_AT_INSTALL"
    fi

    command_output=$(mint bootstrap --link --overwrite y 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ]; then
       echo "mint bootstrap was error. Please make install-mint. $command_output"
       exit 1
    fi
}

function install_mint()  {
    brew install mint
}

if [ ${#@} -eq 1 ]; then
    if [ "${@#"-b"}" = "" ] || [ "${@#"--bootstrap"}" = "" ]; then
        bootstrap_mint
    fi
    if [ "${@#"-i"}" = "" ] || [ "${@#"--install"}" = "" ]; then
        install_mint
    fi
fi
