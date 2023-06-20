import Foundation

public enum BKTError: Error, Equatable {
    case badRequest(message: String)
    case unauthorized(message: String)
    case forbidden(message: String)
    case notFound(message: String)
    case clientClosed(message: String)
    case unavailable(message: String)
    case apiServer(message: String)

    // network errors
    case timeout(message: String, error: Error)
    case network(message: String, error: Error)

    // sdk errors
    case illegalArgument(message: String)
    case illegalState(message: String)

    // unknown errors
    case unknownServer(message: String, error: Error)
    case unknown(message: String, error: Error)

    public static func == (lhs: BKTError, rhs: BKTError) -> Bool {
        switch (lhs, rhs) {
        case (.badRequest(let m1), .badRequest(let m2)),
             (.unauthorized(let m1), .unauthorized(let m2)),
             (.forbidden(let m1), .forbidden(let m2)),
             (.notFound(let m1), .notFound(let m2)),
             (.clientClosed(let m1), .clientClosed(let m2)),
             (.unavailable(let m1), .unavailable(let m2)),
             (.apiServer(let m1), .apiServer(let m2)),
             (.illegalArgument(let m1), .illegalArgument(let m2)),
             (.illegalState(let m1), .illegalState(let m2)):
            return m1 == m2
        case (.timeout(let m1, _), .timeout(let m2, _)),
             (.network(let m1, _), .network(let m2, _)),
             (.unknownServer(let m1, _), .unknownServer(let m2, _)),
             (.unknown(let m1, _), .unknown(let m2, _)):
            return m1 == m2
        default:
            return false
        }
    }
}

extension BKTError : LocalizedError {
    internal init(error: Error) {
        if let bktError = error as? BKTError {
            self = bktError
            return
        }

        if let responseError = error as? ResponseError {
            switch responseError {
            case .unacceptableCode(let code, let errorResponse):
                switch code {
                case 400:
                    self = .badRequest(message: errorResponse?.error.message ?? "BadRequest error")
                case 401:
                    self = .unauthorized(message: errorResponse?.error.message ?? "Unauthorized error")
                case 403:
                    self = .forbidden(message: errorResponse?.error.message ?? "Forbidden error")
                case 404:
                    self = .notFound(message: errorResponse?.error.message ?? "NotFound error")
                case 499:
                    self = .clientClosed(message: errorResponse?.error.message ?? "Client Closed Request error")
                case 500:
                    self = .apiServer(message: errorResponse?.error.message ?? "InternalServer error")
                case 503:
                    self = .unavailable(message: errorResponse?.error.message ?? "Unavailable error")
                default:
                    var message: String = "no error body"
                    if let errorResponse = errorResponse {
                        message = "[\(errorResponse.error.code)] \(errorResponse.error.message)"
                    }
                    self = .unknownServer(message: "Unknown server error: \(message)", error: error)
                }
            case .unknown(let urlResponse):
                var message: String = "no response"
                if let urlResponse = urlResponse as? HTTPURLResponse {
                    message = "[\(urlResponse.statusCode)] \(urlResponse)"
                }
                self = .network(message: "Network connection error: \(message)", error: error)
            }
            return
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorTimedOut {
            self = .timeout(message: "Request timeout error: \(error)", error: error)
        } else {
            self = .unknown(message: "Unknown error: \(error)", error: error)
        }
    }

    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {

        case .badRequest(message: let message):
            return message
        case .unauthorized(message: let message):
            return message
        case .forbidden(message: let message):
            return message
        case .notFound(message: let message):
            return message
        case .clientClosed(message: let message):
            return message
        case .unavailable(message: let message):
            return message
        case .apiServer(message: let message):
            return message
        case .timeout(message: let message, _):
            return message
        case .network(message: let message, _):
            return message
        case .illegalArgument(message: let message):
            return message
        case .illegalState(message: let message):
            return message
        case .unknownServer(message: let message, _):
            return message
        case .unknown(message: let message, _):
            return message
        }
    }

    /// A localized message describing the reason for the failure.
    public var failureReason: String? {
        switch self {

        case .badRequest,
             .unauthorized,
             .forbidden,
             .notFound,
             .clientClosed,
             .unavailable,
             .apiServer,
             .illegalArgument,
             .illegalState:
            return nil

        case .timeout(message: _, error: let error):
            // note: create description for unknown error type
            return "\(error)"

        case .network(message: _, error: let error):
            return "\(error)"

        case .unknownServer(message: _, error: let error):
            return "\(error)"

        case .unknown(message: _, error: let error):
            return "\(error)"
        }
    }
}
