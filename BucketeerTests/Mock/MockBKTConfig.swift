import Foundation
@testable import Bucketeer

extension BKTConfig {
    static let mock1 = mock()

    static func mock(
        eventsFlushInterval: Int64 = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS,
        eventsMaxQueueSize: Int = Constant.DEFAULT_MAX_QUEUE_SIZE,
        pollingInterval: Int64 = Constant.DEFAULT_POLLING_INTERVAL_MILLIS,
        backgroundPollingInterval: Int64 = Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS) -> BKTConfig {
        return BKTConfig(
            apiKey: "api_key_value",
            apiEndpoint: URL(string: "https://test.bucketeer.io")!,
            featureTag: "featureTag1",
            eventsFlushInterval: eventsFlushInterval,
            eventsMaxQueueSize: eventsMaxQueueSize,
            pollingInterval: pollingInterval,
            backgroundPollingInterval: backgroundPollingInterval,
            sdkVersion: "0.0.2",
            appVersion: "1.2.3",
            logger: MockLogger()
        )
    }
}
