import Foundation
@testable import Bucketeer

extension BKTConfig {
    static let mock1 = mock()
    
    static func mock(
        eventsFlushInterval: Int64 = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS,
        eventsMaxQueueSize: Int = Constant.DEFAULT_MAX_QUEUE_SIZE,
        pollingInterval: Int64 = Constant.DEFAULT_POLLING_INTERVAL_MILLIS,
        backgroundPollingInterval: Int64 = Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS) -> BKTConfig {
            let builder = BKTConfig.Builder(apiKey: "api_key_value")
                .with(apiEndpoint: "https://test.bucketeer.io")
                .with(featureTag: "featureTag1")
                .with(eventsFlushInterval: eventsFlushInterval)
                .with(eventsMaxQueueSize: eventsMaxQueueSize)
                .with(pollingInterval: pollingInterval)
                .with(backgroundPollingInterval: backgroundPollingInterval)
                .with(appVersion: "1.2.3")
                .with(logger: MockLogger())
                .with(sdkVersion: "0.0.2")
            return try! builder.build()
        }
}
