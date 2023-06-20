import Foundation

protocol MetricsEventDataProps {
    var apiId: ApiId { get }
    var labels: [String: String] { get }
    var protobufType: String? { get }
}

extension MetricsEventDataProps {
    func uniqueKey() -> String {
        return "\(apiId)::\(protobufType!)"
    }
}

enum MetricsEventData: Hashable {
    case responseLatency(ResponseLatency)
    case responseSize(ResponseSize)
    case timeoutError(TimeoutError)
    case networkError(NetworkError)
    case badRequestError(BadRequestError)
    case unauthorizedError(UnauthorizedError)
    case forbiddenError(ForbiddenError)
    case notFoundError(NotFoundError)
    case clientClosedError(ClientClosedError)
    case unavailableError(UnavailableError)
    case internalSdkError(InternalSdkError)
    case internalServerError(InternalServerError)
    case unknownError(UnknownError)

    struct ResponseLatency: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        let latencySecond: Double
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.LatencyMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
            hasher.combine(latencySecond)
        }
    }

    struct ResponseSize: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        let sizeByte: Int64
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.SizeMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
            hasher.combine(sizeByte)
        }
    }

    struct TimeoutError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.TimeoutErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct NetworkError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.NetworkErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct BadRequestError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.BadRequestErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct UnauthorizedError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.UnauthorizedErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct ForbiddenError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.ForbiddenErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct NotFoundError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.NotFoundErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct ClientClosedError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.ClientClosedRequestErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct UnavailableError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.ServiceUnavailableErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct InternalSdkError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.InternalSdkErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct InternalServerError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.InternalServerErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }

    struct UnknownError: Codable, Hashable, MetricsEventDataProps {
        let apiId: ApiId
        let labels: [String: String]
        var protobufType: String? = "type.googleapis.com/bucketeer.event.client.UnknownErrorMetricsEvent"

        func hash(into hasher: inout Hasher) {
            hasher.combine(apiId)
        }
    }
}
