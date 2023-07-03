import XCTest
@testable import Bucketeer

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
                let _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("apiKey is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
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
                let _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("endpoint is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
    }
    
    func testFeaturedRequired() {
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
                let _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("featureTag is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
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
                let _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("appVersion is required", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
    }
}
