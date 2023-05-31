import Foundation

struct RegisterEventsResponse: Codable {
    let errors: [String: ErrorResponse]

    struct ErrorResponse: Hashable, Codable {
        let retriable: Bool
        let message: String
    }
}
