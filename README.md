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

### Export XCFramework

There are two ways to build and export the XCFramework.

**Option 1 — via Xcode archive (default)**

Uses the standard `xcodebuild` archive approach.

```sh
make create-xcframework-zip
```

**Option 2 — via [Scipio](https://github.com/giginet/Scipio)**

Requires Xcode 26.2+ (Swift 6.1). Uses Scipio to build the XCFramework directly from the Swift package.

```sh
make create-xcframework-scipio
```

## Example App

To run the example app.

You must execute the Makefile `make environment-setup` to set the **API_ENDPOINT** and the **API_KEY**.<br />
It also writes **ENABLE_STREAMING** (`NO` by default, the same as the SDK) to `environment.xcconfig`.<br />
You may need to generate [Xcode project file](https://github.com/bucketeer-io/ios-client-sdk?tab=readme-ov-file#generate-xcode-project-file).

The example app uses the feature tag `ios`, the feature flag `ios_test_002` and the goal `ios_test_002`.<br />
Before you run it, create a string feature flag `ios_test_002` with the feature tag `ios` in your Bucketeer console. Without it the app has no flag to show, and the walkthrough below shows nothing.

### Try a real-time flag update (SSE)

- In `environment.xcconfig`, set `ENABLE_STREAMING = YES`. You can also use the **Streaming** switch at the top of the first screen. Flipping it destroys the client and starts it again in the new mode.
- Run the example app.
- In the Bucketeer console, change the value of the feature flag `ios_test_002`.
- Watch the label on the first screen and the Xcode console. The label changes and an `Evaluation updated. ios_test_002 = <value>` line is printed, pushed by SSE in about a second. With the switch off, the same change takes up to 60 seconds (the polling interval).

If your `environment.xcconfig` was created before this key existed, add the `ENABLE_STREAMING` line yourself or run `make environment-setup` again. A missing value counts as `NO`.

## License

Apache License 2.0, see [LICENSE](https://github.com/bucketeer-io/ios-client-sdk/blob/main/LICENSE).
