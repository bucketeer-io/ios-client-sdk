# Bucketeer Client-side SDK for iOS

[Bucketeer](https://bucketeer.io) is an open-source platform created by [CyberAgent](https://www.cyberagent.co.jp/en) to help teams make better decisions, reduce deployment lead time and release risk through feature flags. Bucketeer offers advanced features like dark launches and staged rollouts that perform limited releases based on user attributes, devices, and other segments.

[Getting started](https://docs.bucketeer.io/sdk/client-side/ios) using Bucketeer SDK.

## Supported iOS and Xcode versions

Bucketeer SDK has been tested across iOS and tvOS devices.

Minimum build tool versions:

| Tool  | Version |
| ----- | ------- |
| Xcode | 13.1+   |
| Swift | 5.0+    |

Minimum device platforms:

| Platform | Version |
| -------- | ------- |
| iOS      | 11.0    |
| tvOS     | 11.0    |

## Installation

See our [documentation](https://docs.bucketeer.io/sdk/client-side/ios) to install the SDK.

## Contributing

We would ❤️ for you to contribute to Bucketeer and help improve it! Anyone can use and enjoy it!

Please follow our contribution guide [here](https://docs.bucketeer.io/contribution-guide/).

## Development

### Development with Xcode

Open Xcode and import `ios-client-sdk`.

### Development with command line

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

To install the app via an emulator, set the following values in the `Info.plist`.

- apiEndpoint
- apiKey

## License

Apache License 2.0, see [LICENSE](https://github.com/bucketeer-io/ios-client-sdk/blob/main/LICENSE).
