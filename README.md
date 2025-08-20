# Bucketeer Client-side SDK for iOS

[Bucketeer](https://bucketeer.io) is an open-source platform created by [CyberAgent](https://www.cyberagent.co.jp/en) to help teams make better decisions, reduce deployment lead time and release risk through feature flags. Bucketeer offers advanced features like dark launches and staged rollouts that perform limited releases based on user attributes, devices, and other segments.

[Getting started](https://docs.bucketeer.io/sdk/client-side/ios) using Bucketeer SDK.

## Supported iOS and Xcode versions

Bucketeer SDK has been tested across iOS and tvOS devices.

Minimum build tool versions:

| Tool  | Version |
| ----- | ------- |
| Xcode | 13.1+   |
| Swift | 5.3+    |

Minimum device platforms:

| Platform | Version |
| -------- | ------- |
| iOS      | 12.0    |
| tvOS     | 12.0    |

## Installation

See our [documentation](https://docs.bucketeer.io/sdk/client-side/ios) to install the SDK.

## Contributing

We would ❤️ for you to contribute to Bucketeer and help improve it! Anyone can use and enjoy it!

Please follow our contribution guide [here](https://docs.bucketeer.io/contribution-guide/).

## Development

### Setup the library management
This project use [mint](https://github.com/yonaskolb/Mint) for library management.

#### Install
```sh
make install-mint
```
※You need [homebrew](https://brew.sh/) to install mint.

#### Install library
```sh
make bootstrap-mint
```

### Setup the environment xcconfig file

Execute the following Makefile to create the environment xcconfig file.<br />
This will set the **API_ENDPOINT** and the **API_KEY** for E2E Tests and the Example App.

```sh
make environment-setup
```
### Generate Xcode project file

Generate `.xcodeproj` using [XcodeGen](https://github.com/yonaskolb/XcodeGen).<br />
If `project.yml` is updated, it should be generated.

```sh
make generate-project-file
```

### Development with Xcode 

Open Xcode and import `ios-client-sdk`.<br />
※You may need to generate [Xcode project file](https://github.com/bucketeer-io/ios-client-sdk?tab=readme-ov-file#generate-xcode-project-file).

### Development with command line

※You may need to generate [Xcode project file](https://github.com/bucketeer-io/ios-client-sdk?tab=readme-ov-file#generate-xcode-project-file).

Build SDK

```sh
make build
```

Build Example App

```sh
make build-example
```

To run the E2E test, set the following environment variables before building it. There is no need to set it for unit testing.

- E2E_API_ENDPOINT
- E2E_API_KEY

```sh
make build-for-testing E2E_API_ENDPOINT=<YOUR_API_ENDPOINT> E2E_API_KEY=<YOUR_API_KEY>
```

Run Unit Tests

```sh
make test-without-building
```

Run E2E Tests

```sh
make e2e-without-building
```

## Example App

To run the example app.

You must execute the Makefile `make environment-setup` to set the **API_ENDPOINT** and the **API_KEY**.<br />
You may need to generate [Xcode project file](https://github.com/bucketeer-io/ios-client-sdk?tab=readme-ov-file#generate-xcode-project-file).

## License

Apache License 2.0, see [LICENSE](https://github.com/bucketeer-io/ios-client-sdk/blob/main/LICENSE).
