import Foundation

struct ErrorResponse: Hashable, Codable {
    let error: ErrorDetail

    struct ErrorDetail: Hashable, Codable {
        let code: Int
        let message: String
    }
}
