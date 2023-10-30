#!/bin/bash

MINT_LIBRARY_PATH_AT_INSTALL="mint/lib"
MINT_LINK_PATH_AT_INSTALL="mint/bin"

function bootstrap_mint() {
    if [ "$CI" = "" ]; then
        export MINT_LINK_PATH="$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH="$MINT_LIBRARY_PATH_AT_INSTALL"
    else
        export MINT_LINK_PATH=".$MINT_LINK_PATH_AT_INSTALL"
        export MINT_PATH=".$MINT_LIBRARY_PATH_AT_INSTALL"
    fi

    result_search_mint=$(brew list | grep mint 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ] || [result_search_mint=""]; then
        echo "mint doesn't install. $command_output"
        install_mint
    fi

    command_output=$(mint bootstrap --link --overwrite y 2>&1)
    exit_status=$?

    if [ $exit_status -ne 0 ]; then
        echo "mint bootstrap was error. $command_output"
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
