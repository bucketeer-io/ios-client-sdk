import Foundation

enum EventData: Hashable {
    case goal(Goal)
    case evaluation(Evaluation)
    case metrics(Metrics)

    struct Goal: Codable, Hashable {
        let timestamp: Int64
        let goalId: String
        let userId: String
        let value: Double
        let user: User
        let tag: String
        let sourceId: SourceID
        var sdkVersion: String?
        var metadata: [String: String]?
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.GoalEvent"
    }

    struct Evaluation: Codable, Hashable {
        let timestamp: Int64
        let featureId: String
        var featureVersion: Int = 0
        let userId: String
        var variationId: String = ""
        let user: User
        let reason: Reason
        let tag: String
        let sourceId: SourceID
        var sdkVersion: String?
        var metadata: [String: String]?
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.EvaluationEvent"
    }

    struct Metrics: Codable, Hashable {
        let timestamp: Int64
        let event: MetricsEventData
        let type: MetricsEventType
        let sourceId: SourceID
        var sdkVersion: String?
        var metadata: [String: String]?
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.MetricsEvent"

        enum CodingKeys: String, CodingKey {
            case timestamp
            case event
            case type
            case sourceId
            case sdkVersion
            case metadata
            case protobufType
        }

        init(timestamp: Int64, event: MetricsEventData, type: MetricsEventType, sourceId: SourceID, sdk_version: String, metadata: [String: String]?) {
            self.timestamp = timestamp
            self.event = event
            self.type = type
            self.sourceId = sourceId
            self.sdkVersion = sdk_version
            self.metadata = metadata
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.timestamp = try container.decode(Int64.self, forKey: .timestamp)
            self.type = try container.decode(MetricsEventType.self, forKey: .type)
            self.sdkVersion = try container.decodeIfPresent(String.self, forKey: .sdkVersion)
            self.sourceId = try container.decode(SourceID.self, forKey: .sourceId)
            self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
            switch self.type {
            case .responseLatency:
                let data = try container.decode(MetricsEventData.ResponseLatency.self, forKey: .event)
                self.event = .responseLatency(data)
            case .responseSize:
                let data = try container.decode(MetricsEventData.ResponseSize.self, forKey: .event)
                self.event = .responseSize(data)
            case .timeoutError:
                let data = try container.decode(MetricsEventData.TimeoutError.self, forKey: .event)
                self.event = .timeoutError(data)
            case .networkError:
                let data = try container.decode(MetricsEventData.NetworkError.self, forKey: .event)
                self.event = .networkError(data)
            case .badRequestError:
                let data = try container.decode(MetricsEventData.BadRequestError.self, forKey: .event)
                self.event = .badRequestError(data)
            case .unauthorizedError:
                let data = try container.decode(MetricsEventData.UnauthorizedError.self, forKey: .event)
                self.event = .unauthorizedError(data)
            case .forbiddenError:
                let data = try container.decode(MetricsEventData.ForbiddenError.self, forKey: .event)
                self.event = .forbiddenError(data)
            case .notFoundError:
                let data = try container.decode(MetricsEventData.NotFoundError.self, forKey: .event)
                self.event = .notFoundError(data)
            case .clientClosedError:
                let data = try container.decode(MetricsEventData.ClientClosedError.self, forKey: .event)
                self.event = .clientClosedError(data)
            case .unavailableError:
                let data = try container.decode(MetricsEventData.UnavailableError.self, forKey: .event)
                self.event = .unavailableError(data)
            case .internalError:
                let data = try container.decode(MetricsEventData.InternalSdkError.self, forKey: .event)
                self.event = .internalSdkError(data)
            case .internalServerError:
                let data = try container.decode(MetricsEventData.InternalServerError.self, forKey: .event)
                self.event = .internalServerError(data)
            case .unknownError:
                let data = try container.decode(MetricsEventData.UnknownError.self, forKey: .event)
                self.event = .unknownError(data)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(type, forKey: .type)
            try container.encode(sourceId, forKey: .sourceId)
            if let sdkVersion {
                try container.encode(sdkVersion, forKey: .sdkVersion)
            }
            try container.encode(metadata, forKey: .metadata)
            switch self.event {
            case .responseLatency(let eventData):
                try container.encode(eventData, forKey: .event)
            case .responseSize(let eventData):
                try container.encode(eventData, forKey: .event)
            case .timeoutError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .networkError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .badRequestError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .unauthorizedError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .forbiddenError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .notFoundError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .clientClosedError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .unavailableError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .internalSdkError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .internalServerError(let eventData):
                try container.encode(eventData, forKey: .event)
            case .unknownError(let eventData):
                try container.encode(eventData, forKey: .event)
            }
            if let protobufType {
                try container.encode(protobufType, forKey: .protobufType)
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(event)
            hasher.combine(type)
        }
    }
}
