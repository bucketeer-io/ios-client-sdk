import UIKit

public struct BKTConfig {
    let apiKey: String
    let apiEndpoint: URL
    let featureTag: String
    let eventsFlushInterval: Int64
    let eventsMaxQueueSize: Int
    let pollingInterval: Int64
    let backgroundPollingInterval: Int64
    let sourceId: SourceID
    let sdkVersion: String
    let appVersion: String
    let logger: BKTLogger?
    let wrapperSdkVersion: String?
    let wrapperSdkSourceId: Int?

    public class Builder {
        private(set) var apiKey: String?
        private(set) var apiEndpoint: String?
        private(set) var featureTag: String?
        private(set) var eventsFlushInterval: Int64?
        private(set) var eventsMaxQueueSize: Int?
        private(set) var pollingInterval: Int64?
        private(set) var backgroundPollingInterval: Int64?
        private(set) var appVersion: String?
        private(set) var logger: BKTLogger?
        private(set) var wrapperSdkVersion: String?
        private(set) var wrapperSdkSourceId: Int?

        public init() {}

        public func with(apiKey: String) -> Builder {
            self.apiKey = apiKey
            return self
        }

        public func with(apiEndpoint: String) -> Builder {
            self.apiEndpoint = apiEndpoint
            return self
        }

        public func with(featureTag: String) -> Builder {
            self.featureTag = featureTag
            return self
        }

        public func with(eventsFlushInterval: Int64) -> Builder {
            self.eventsFlushInterval = eventsFlushInterval
            return self
        }

        public func with(eventsMaxQueueSize: Int) -> Builder {
            self.eventsMaxQueueSize = eventsMaxQueueSize
            return self
        }

        public func with(pollingInterval: Int64) -> Builder {
            self.pollingInterval = pollingInterval
            return self
        }

        public func with(backgroundPollingInterval: Int64) -> Builder {
            self.backgroundPollingInterval = backgroundPollingInterval
            return self
        }

        public func with(appVersion: String) -> Builder {
            self.appVersion = appVersion
            return self
        }

        public func with(wrapperSdkVersion: String) -> Builder {
            self.wrapperSdkVersion = wrapperSdkVersion
            return self
        }

        public func with(wrapperSdkSourceId: Int) -> Builder {
            self.wrapperSdkSourceId = wrapperSdkSourceId
            return self
        }

        public func with(logger: BKTLogger) -> Builder {
            self.logger = logger
            return self
        }

        public func build() throws -> BKTConfig {
            return try BKTConfig.init(with: self)
        }
    }
}

extension BKTConfig {
    // Public init - that will support to init of the BKTConfig like before we add the Builder.
    // So it will not create breaking changes
    @available(*, deprecated, message: "Use the Builder class instead. Check the documentation for more information.")
    public init(
        apiKey: String,
        apiEndpoint: String,
        featureTag: String,
        eventsFlushInterval: Int64 = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS,
        eventsMaxQueueSize: Int = Constant.DEFAULT_MAX_QUEUE_SIZE,
        pollingInterval: Int64 = Constant.DEFAULT_POLLING_INTERVAL_MILLIS,
        backgroundPollingInterval: Int64 = Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS,
        appVersion: String,
        logger: BKTLogger? = nil
    ) throws {
        // Delegate to Builder to keep a single validation/normalization path.
        let builder = BKTConfig.Builder()
            .with(apiKey: apiKey)
            .with(apiEndpoint: apiEndpoint)
            .with(featureTag: featureTag)
            .with(eventsFlushInterval: eventsFlushInterval)
            .with(eventsMaxQueueSize: eventsMaxQueueSize)
            .with(pollingInterval: pollingInterval)
            .with(backgroundPollingInterval: backgroundPollingInterval)
            .with(appVersion: appVersion)
        if let logger = logger {
            _ = builder.with(logger: logger)
        }
        // Build and assign to self
        self = try builder.build()
    }

    private init(with builder: Builder) throws {
        guard let apiKey = builder.apiKey, apiKey.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "apiKey is required")
        }
        guard let apiEndpoint = builder.apiEndpoint, apiEndpoint.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "apiEndpoint is required")
        }
        guard let appVersion = builder.appVersion, appVersion.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "appVersion is required")
        }

        // refs: JS SDK PR https://github.com/bucketeer-io/javascript-client-sdk/pull/91
        // Allow Builder.featureTag could be nill
        // So the default value of the BKTConfig will be ""
        let featureTag = builder.featureTag ?? ""
        let logger = builder.logger
        // Set default intervals if needed
        var pollingInterval: Int64 = builder.pollingInterval ?? Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        var backgroundPollingInterval: Int64 = builder.backgroundPollingInterval ?? Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        var eventsFlushInterval: Int64 = builder.eventsFlushInterval ?? Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        var eventsMaxQueueSize = builder.eventsMaxQueueSize ?? Constant.DEFAULT_MAX_QUEUE_SIZE

        guard !apiKey.isEmpty else {
            throw BKTError.illegalArgument(message: "apiKey is required")
        }
        guard let apiEndpointURL = URL(string: apiEndpoint) else {
            throw BKTError.illegalArgument(message: "apiEndpoint is required")
        }
        guard !appVersion.isEmpty else {
            throw BKTError.illegalArgument(message: "appVersion is required")
        }

        if pollingInterval < Constant.MINIMUM_POLLING_INTERVAL_MILLIS {
            logger?.warn(message: "pollingInterval: \(pollingInterval) is set but must be above \(Constant.MINIMUM_POLLING_INTERVAL_MILLIS)")
            pollingInterval = Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        }

        if backgroundPollingInterval < Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS {
            logger?.warn(message: "backgroundPollingInterval: \(backgroundPollingInterval) is set but must be above \(Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS)")
            backgroundPollingInterval = Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        }

        if eventsFlushInterval < Constant.MINIMUM_FLUSH_INTERVAL_MILLIS {
            logger?.warn(message: "eventsFlushInterval: \(eventsFlushInterval) is set but must be above \(Constant.MINIMUM_FLUSH_INTERVAL_MILLIS)")
            eventsFlushInterval = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        }
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpointURL
        self.featureTag = featureTag
        self.eventsFlushInterval = eventsFlushInterval
        self.eventsMaxQueueSize = eventsMaxQueueSize
        self.pollingInterval = pollingInterval
        self.backgroundPollingInterval = backgroundPollingInterval
        self.wrapperSdkVersion = builder.wrapperSdkVersion
        self.wrapperSdkSourceId = builder.wrapperSdkSourceId
        let resolvedSdkSourceId = try resolveSdkSourceId(wrapperSdkSourceId: builder.wrapperSdkSourceId)
        let resolvedSdkVersion = try resolveSdkVersion(
            resolveSdkSourceId: resolvedSdkSourceId,
            wrapperSdkVersion: builder.wrapperSdkVersion
        )
        self.sourceId = resolvedSdkSourceId
        self.sdkVersion = resolvedSdkVersion
        self.appVersion = appVersion
        self.logger = logger
    }
}

private func resolveSdkSourceId(wrapperSdkSourceId: Int?) throws -> SourceID {
    guard let wrapperSdkSourceId = wrapperSdkSourceId else {
        return .ios // native
    }
    // There is only one supported wrapperSdkSourceId (flutter) for now
    if let sourceId = SourceID(rawValue: wrapperSdkSourceId), supportedWrapperSdkSourceIds.contains(sourceId) {
        return sourceId
    }
    throw BKTError.illegalArgument(message: "Unsupported wrapperSdkSourceId: \(wrapperSdkSourceId)")
}

private func resolveSdkVersion(resolveSdkSourceId: SourceID, wrapperSdkVersion: String?) throws -> String {
    if resolveSdkSourceId != .ios {
        if let wrapperSdkVersion = wrapperSdkVersion, wrapperSdkVersion.isNotEmpty() {
            return wrapperSdkVersion
        }
        throw BKTError.illegalArgument(message: "wrapperSdkVersion is required when sourceId is not iOS")
    }
    return Version.current
}

private let supportedWrapperSdkSourceIds: [SourceID] = [.flutter, .openFeatureSwift]

fileprivate extension String {
    func isNotEmpty() -> Bool {
        // We will not check all case
        return count > 0
    }
}
