import Foundation
@testable import Bucketeer

extension BKTConfig {
    static let mock1 = mock()

    static func mock(
        eventsFlushInterval: Int64 = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS,
        eventsMaxQueueSize: Int = Constant.DEFAULT_MAX_QUEUE_SIZE,
        pollingInterval: Int64 = Constant.DEFAULT_POLLING_INTERVAL_MILLIS,
        backgroundPollingInterval: Int64 = Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS,
        featureTag: String = "featureTag1") -> BKTConfig {
        // Direct init BKTConfig and bypass all validations
        // It could only happen with internal access
        return BKTConfig(
            apiKey: "api_key_value",
            apiEndpoint: URL(string: "https://test.bucketeer.io")!,
            featureTag: featureTag,
            eventsFlushInterval: eventsFlushInterval,
            eventsMaxQueueSize: eventsMaxQueueSize,
            pollingInterval: pollingInterval,
            backgroundPollingInterval: backgroundPollingInterval,
            sourceId: .ios,
            sdkVersion: "0.0.2",
            appVersion: "1.2.3",
            logger: MockLogger(),
            wrapperSdkVersion: nil,
            wrapperSdkSourceId: nil,
        )
    }
}
