#!/bin/bash

confirm_api_endpoint () {
    echo "Please input your API_ENDPOINT and press enter. E.g. api.bucketeer.io"
    read input

    if [ -z $input ]; then
        confirm_api_url
    fi
    API_ENDPOINT=$input
}

confirm_api_key () {
    echo "Please input your API_KEY and press enter."
    read input

    if [ -z $input ]; then
        confirm_sdk_key
    fi
    API_KEY=$input
}

if [ "$CI" = "" ]; then
    confirm_api_endpoint
    confirm_api_key
fi

# Because the xcconfig doesn't support double slash,
# we need to workaround separating it using another variable
xcconfig=$(cat << EOF
SLASH = /
API_ENDPOINT = https:\$(SLASH)/${API_ENDPOINT}
API_KEY = ${API_KEY}
EOF
)

echo "$xcconfig" > ./environment.xcconfig
echo "Updated ./environment.xcconfig"
