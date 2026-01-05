import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length
final class BKTConfigTests: XCTestCase {

    func testCreateConfig() {
        let logger = MockLogger()
        // Not set interval values
        var builder = BKTConfig.Builder()
            .with(apiKey: "api_key_value")
            .with(apiEndpoint: "https://test.bucketeer.io")
            .with(featureTag: "featureTag1")
            .with(appVersion: "1.2.3")
            .with(logger: logger)

        let config1 = try? builder.build()
        XCTAssertNotNil(config1, "BKTConfig should not be null")

        let eventsFlushInterval1 = config1!.eventsFlushInterval
        XCTAssertEqual(eventsFlushInterval1,
                       Constant.MINIMUM_FLUSH_INTERVAL_MILLIS,
                       "eventsFlushInterval: \(eventsFlushInterval1) must be equal \(Constant.MINIMUM_FLUSH_INTERVAL_MILLIS)")

        let backgroundPollingInterval1 = config1!.backgroundPollingInterval
        XCTAssertEqual(backgroundPollingInterval1,
                       Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS,
                       "backgroundPollingInterval: \(backgroundPollingInterval1) must be equal \(Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS)")

        let pollingInterval1 = config1!.pollingInterval
        XCTAssertEqual(pollingInterval1,
                       Constant.MINIMUM_POLLING_INTERVAL_MILLIS,
                       "pollingInterval: \(pollingInterval1) must be equal \(Constant.MINIMUM_POLLING_INTERVAL_MILLIS)")

        // Set interval settings but they are too small
        builder = builder.with(eventsFlushInterval: 50)
            .with(eventsMaxQueueSize: 3)
            .with(pollingInterval: 100)
            .with(backgroundPollingInterval: 1000)

        let config2 = try? builder.build()
        XCTAssertNotNil(config2, "BKTConfig should not be null")

        let eventsFlushInterval2 = config2!.eventsFlushInterval
        XCTAssertEqual(eventsFlushInterval2,
                       Constant.MINIMUM_FLUSH_INTERVAL_MILLIS,
                       "eventsFlushInterval: \(eventsFlushInterval2) is set but must be above \(Constant.MINIMUM_FLUSH_INTERVAL_MILLIS)")

        let backgroundPollingInterval2 = config2!.backgroundPollingInterval
        XCTAssertEqual(backgroundPollingInterval2,
                       Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS,
                       "backgroundPollingInterval: \(backgroundPollingInterval2) is set but must be above \(Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS)")

        let pollingInterval2 = config2!.pollingInterval
        XCTAssertEqual(pollingInterval2,
                       Constant.MINIMUM_POLLING_INTERVAL_MILLIS,
                       "pollingInterval: \(pollingInterval2) is set but must be above \(Constant.MINIMUM_POLLING_INTERVAL_MILLIS)")

        // Set interval settings but now they are bigger enough
        builder = builder.with(eventsFlushInterval: 60_000)
            .with(eventsMaxQueueSize: 3)
            .with(pollingInterval: 60_000)
            .with(backgroundPollingInterval: 1_200_000)

        let config3 = try? builder.build()
        XCTAssertNotNil(config3, "BKTConfig should not be null")

        let eventsFlushInterval3 = config3!.eventsFlushInterval
        XCTAssertEqual(eventsFlushInterval3,
                       60_000,
                       "eventsFlushInterval: \(eventsFlushInterval3) must be equal \(60_000)")

        let backgroundPollingInterval3 = config3!.backgroundPollingInterval
        XCTAssertEqual(backgroundPollingInterval3,
                       1_200_000,
                       "backgroundPollingInterval: \(backgroundPollingInterval3) must be equal \(1_200_000)")

        let pollingInterval3 = config3!.pollingInterval
        XCTAssertEqual(pollingInterval3,
                       60_000,
                       "pollingInterval: \(pollingInterval3) must be equal \(60_000)")

        // Checking other property should match with the user input
        XCTAssertEqual("api_key_value",
                       config3?.apiKey,
                       "api_key does not match")
        XCTAssertEqual("https://test.bucketeer.io",
                       config3?.apiEndpoint.absoluteString,
                       "apiEndpoint does not match")
        XCTAssertEqual("featureTag1",
                       config3?.featureTag,
                       "featureTag1 does not match")
        XCTAssertEqual(Version.current,
                       config3?.sdkVersion,
                       "sdkVersion does not match")
        XCTAssertEqual("1.2.3",
                       config3?.appVersion,
                       "appVersion does not match")
        XCTAssertNotNil(config3?.logger, "logger should not nil")
    }

    func testAPIKeyRequired() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let builders = [
            BKTConfig.Builder()
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag1")
                .with(appVersion: "1.2.3"),
            BKTConfig.Builder()
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag1")
                .with(appVersion: "1.2.3")
        ]

        builders.forEach { builder in
            do {
                _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("apiKey is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testAPIEndpointRequired() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let builders = [
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer")
                .with(featureTag: "featureTag1")
                .with(appVersion: "1.2.3"),
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "")
                .with(featureTag: "featureTag1")
                .with(appVersion: "1.2.3"),
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(featureTag: "featureTag1")
                .with(appVersion: "1.2.3")
        ]

        builders.forEach { builder in
            do {
                _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("apiEndpoint is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testFeaturedTagIsOptional() {
        // https://github.com/bucketeer-io/android-client-sdk/issues/69
        // Change the featureTag setting to be optional in the BKTConfig
        // featured_tag is no longer required, it could be null when using `BKTConfig.Builder`
        // when we did not set feature_tag on the Builder
        // the value of BKTConfig.feature_tag should be empty string ""
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let builders = [
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "")
                .with(appVersion: "1.2.3"),
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(appVersion: "1.2.3")
        ]

        builders.forEach { builder in
            do {
                let config = try builder.build()
                XCTAssertEqual(config.featureTag, "", "explicitly passing nil or empty string to featureTag results in empty string")
                expectation.fulfill()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("builder.build() should success", message)
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testAppVersionRequired() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        let builders = [
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag1")
                .with(appVersion: ""),
            BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag1")
        ]

        builders.forEach { builder in
            do {
                _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("appVersion is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testDefaultSourceIdIsIOS() {
        let builder = BKTConfig.Builder()
            .with(apiKey: "api_key_value")
            .with(apiEndpoint: "https://test.bucketeer.io")
            .with(featureTag: "featureTag")
            .with(appVersion: "1.0.0")

        do {
            let config = try builder.build()
            XCTAssertEqual(config.sourceId, SourceID.ios)
            XCTAssertEqual(config.sdkVersion, Version.current)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResolveSourceIdFromWrapperSDKSourceId() {
        let supportedIds = [SourceID.flutter.rawValue, SourceID.openFeatureSwift.rawValue]
        for id in supportedIds {
            let builder = BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag")
                .with(appVersion: "1.0.0")
                .with(wrapperSdkSourceId: id)
                .with(wrapperSdkVersion: "2.3.0")
            do {
                let config = try builder.build()
                XCTAssertEqual(config.sourceId, SourceID(rawValue: id))
                XCTAssertEqual(config.sdkVersion, "2.3.0")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testOnlyAllowSupportedWrapperSDKs() {
        // Only Flutter (8) and OpenFeature Swift (101) are supported currently
        let unsupportedIds = [0, 1, 2, 3, 4, 5, 6, 9, 10, 100, 102, 103, 104, 999, -1]
        for id in unsupportedIds {
            let builder = BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag")
                .with(appVersion: "1.0.0")
                .with(wrapperSdkSourceId: id)
                .with(wrapperSdkVersion: "1.0.0")
            do {
                _ = try builder.build()
                XCTFail("Expected failure for wrapperSdkSourceId \(id)")
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("Unsupported wrapperSdkSourceId: \(id)", message)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testWrapperSDKVersionIsRequiredIfWrapperSDKSourceIdSet() {
        // Case 1: missing wrapperSdkVersion
        var builder = BKTConfig.Builder()
            .with(apiKey: "api_key_value")
            .with(apiEndpoint: "https://test.bucketeer.io")
            .with(featureTag: "featureTag")
            .with(appVersion: "1.0.0")
            .with(wrapperSdkSourceId: SourceID.flutter.rawValue)

        do {
            _ = try builder.build()
            XCTFail("Expected failure when wrapperSdkVersion is missing")
        } catch BKTError.illegalArgument(let message) {
            XCTAssertEqual("wrapperSdkVersion is required when sourceId is not iOS", message)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Case 2: empty wrapperSdkVersion
        builder = builder.with(wrapperSdkVersion: "")
        do {
            _ = try builder.build()
            XCTFail("Expected failure when wrapperSdkVersion is empty")
        } catch BKTError.illegalArgument(let message) {
            XCTAssertEqual("wrapperSdkVersion is required when sourceId is not iOS", message)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSDKVersionForVariousSourceIds() {
        struct SDKTestCase {
            let builder: BKTConfig.Builder
            let caseName: String
            let expectedSourceId: SourceID
            let expectedVersion: String
        }

        func makeBaseBuilder() -> BKTConfig.Builder {
            return BKTConfig.Builder()
                .with(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag")
                .with(appVersion: "1.0.0")
        }

        let testCases: [SDKTestCase] = [
            SDKTestCase(
                builder: makeBaseBuilder(),
                caseName: "iOS",
                expectedSourceId: .ios,
                expectedVersion: Version.current
            ),
            SDKTestCase(
                builder: makeBaseBuilder()
                    .with(wrapperSdkSourceId: SourceID.flutter.rawValue)
                    .with(wrapperSdkVersion: "2.0.0"),
                caseName: "Flutter",
                expectedSourceId: .flutter,
                expectedVersion: "2.0.0"
            ),
            SDKTestCase(
                builder: makeBaseBuilder()
                    .with(wrapperSdkSourceId: SourceID.openFeatureSwift.rawValue)
                    .with(wrapperSdkVersion: "3.1.4"),
                caseName: "OpenFeatureSwift",
                expectedSourceId: .openFeatureSwift,
                expectedVersion: "3.1.4"
            )
        ]

        for test in testCases {
            do {
                let config = try test.builder.build()
                let sdkInfo = config.toSDKInfo()
                XCTAssertEqual(sdkInfo.sourceId, test.expectedSourceId, "SourceId failed for case: \(test.caseName)")
                XCTAssertEqual(sdkInfo.sdkVersion, test.expectedVersion, "SdkVersion failed for case: \(test.caseName)")
            } catch {
                XCTFail("Unexpected error for case \(test.caseName): \(error)")
            }
        }
    }
}
// swiftlint:enable type_body_length
