import Foundation

enum MetricsEventType: Int, Codable, Hashable {
    case unknownError = 0
    case responseLatency
    case responseSize
    case timeoutError
    case networkError
    case internalError
    case badRequestError
    case unauthorizedError
    case forbiddenError
    case notFoundError
    case clientClosedError
    case unavailableError
    case internalServerError
}
