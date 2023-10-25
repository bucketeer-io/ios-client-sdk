#!/bin/bash

source ./hack/mint.sh

function run() {
    PROJECT_DIR=$(xcodebuild -showBuildSettings | grep "PROJECT_DIR = .*" | sed "s/PROJECT_DIR = //g" | sed "s/ //g")
    echo "PROJECT_DIR=$PROJECT_DIR"

    SWIFTLINT_FILE_PATH="$PROJECT_DIR/$MINT_LINK_PATH_AT_INSTALL/swiftlint"

    if [ ! -e $SWIFTLINT_FILE_PATH ]; then
        echo "swiftlint: not found."
        mint_bootstrap
    fi
    $SWIFTLINT_FILE_PATH
}

if [ ${#@} -eq 1 ]; then
    if [ "${@#"-r"}" = "" ] || [ "${@#"--run"}" = "" ]; then
        run
    fi
fi