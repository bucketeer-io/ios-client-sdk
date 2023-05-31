import Foundation

public struct BKTUser {
    let id: String
    let attr: [String: String]
}

extension BKTUser {
    public init(
        id: String,
        attributes: [String: String] = [:]
    ) throws {
        guard !id.isEmpty else {
            throw BKTError.illegalArgument(message: "The user id is required.")
        }
        self = BKTUser(id: id, attr: attributes)
    }
}
