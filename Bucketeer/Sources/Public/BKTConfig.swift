import UIKit

public struct BKTConfig {
    let apiKey: String
    let apiEndpoint: URL
    let featureTag: String
    let eventsFlushInterval: Int64
    let eventsMaxQueueSize: Int
    let pollingInterval: Int64
    let backgroundPollingInterval: Int64
    let sdkVersion: String
    let appVersion: String
    let logger: BKTLogger?
}

public class BKTConfigBuilder{
    private(set) var apiKey: String?
    private(set) var apiEndpoint: String?
    private(set) var featureTag: String?
    private(set) var eventsFlushInterval: Int64?
    private(set) var eventsMaxQueueSize: Int?
    private(set) var pollingInterval: Int64?
    private(set) var backgroundPollingInterval: Int64?
    private(set) var sdkVersion: String?
    private(set) var appVersion: String?
    private(set) var logger: BKTLogger?
    
    func with(apiKey: String?) -> BKTConfigBuilder {
        self.apiKey = apiKey
        return self
    }
    
    func with(apiEndpoint: String?) -> BKTConfigBuilder {
        self.apiEndpoint = apiEndpoint
        return self
    }
    
    func with(featureTag: String?) -> BKTConfigBuilder {
        self.featureTag = featureTag
        return self
    }
    
    func with(eventsFlushInterval: Int64?) -> BKTConfigBuilder {
        self.eventsFlushInterval = eventsFlushInterval
        return self
    }
    
    func with(eventsMaxQueueSize: Int?) -> BKTConfigBuilder {
        self.eventsMaxQueueSize = eventsMaxQueueSize
        return self
    }
    
    func with(pollingInterval: Int64?) -> BKTConfigBuilder {
        self.pollingInterval = pollingInterval
        return self
    }
    
    func with(backgroundPollingInterval: Int64?) -> BKTConfigBuilder {
        self.backgroundPollingInterval = backgroundPollingInterval
        return self
    }
    
    func with(sdkVersion: String?) -> BKTConfigBuilder {
        self.sdkVersion = sdkVersion
        return self
    }
    
    func with(appVersion: String?) -> BKTConfigBuilder {
        self.appVersion = appVersion
        return self
    }
    
    func with(logger: BKTLogger?) -> BKTConfigBuilder {
        self.logger = logger
        return self
    }
    
    func build() throws -> BKTConfig {
        guard let apiKeyForSDK = apiKey, apiKeyForSDK.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "apiKey is required")
        }
        guard let endpoint = apiEndpoint, let apiEndpointURL = URL(string: endpoint) else {
            throw BKTError.illegalArgument(message: "endpoint is required")
        }
        guard let tag = featureTag, tag.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "featureTag is required")
        }
        guard let version = appVersion, version.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "appVersion is required")
        }
        
        var pollingInterval : Int64 = pollingInterval ?? Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        if pollingInterval < Constant.MINIMUM_POLLING_INTERVAL_MILLIS {
            logger?.warn(message: "pollingInterval: \(pollingInterval) is set but must be above \(Constant.MINIMUM_POLLING_INTERVAL_MILLIS)")
            pollingInterval = Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        }
        var backgroundPollingInterval : Int64 = backgroundPollingInterval ?? Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        if backgroundPollingInterval < Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS {
            logger?.warn(message: "backgroundPollingInterval: \(backgroundPollingInterval) is set but must be above \(Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS)")
            backgroundPollingInterval = Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        }
        var eventsFlushInterval: Int64 = eventsFlushInterval ?? Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        if eventsFlushInterval < Constant.MINIMUM_FLUSH_INTERVAL_MILLIS {
            logger?.warn(message: "eventsFlushInterval: \(eventsFlushInterval) is set but must be above \(Constant.MINIMUM_FLUSH_INTERVAL_MILLIS)")
            eventsFlushInterval = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        }
        
        return try BKTConfig.init(
            apiKey: apiKeyForSDK,
            apiEndpoint: apiEndpointURL,
            featureTag: tag,
            eventsFlushInterval: eventsFlushInterval,
            eventsMaxQueueSize: eventsMaxQueueSize ?? Constant.DEFAULT_MAX_QUEUE_SIZE,
            pollingInterval: pollingInterval,
            backgroundPollingInterval: backgroundPollingInterval,
            appVersion: version)
    }
}

fileprivate extension String {
    func isNotEmpty() -> Bool {
        // We will not check all case
        return count > 0
    }
}

fileprivate extension BKTConfig {
    init(
        apiKey: String,
        apiEndpoint: URL,
        featureTag: String,
        eventsFlushInterval: Int64,
        eventsMaxQueueSize: Int,
        pollingInterval: Int64,
        backgroundPollingInterval: Int64,
        appVersion: String,
        logger: BKTLogger? = nil
    ) throws {
        self = BKTConfig(
            apiKey: apiKey,
            apiEndpoint: apiEndpoint,
            featureTag: featureTag,
            eventsFlushInterval: eventsFlushInterval,
            eventsMaxQueueSize: eventsMaxQueueSize,
            pollingInterval: pollingInterval,
            backgroundPollingInterval: backgroundPollingInterval,
            sdkVersion: Version.current,
            appVersion: appVersion,
            logger: logger
        )
    }
}
