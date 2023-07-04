import Foundation

public struct BKTUser {
    public let id: String
    public let attr: [String: String]

    public class Builder {
        private(set) var id: String?
        private(set) var attributes: [String: String] = [:]

        public init() {}

        public func with(id: String) -> Builder {
            self.id = id
            return self
        }

        public func with(attributes: [String: String]) -> Builder {
            self.attributes = attributes
            return self
        }

        public func build() throws -> BKTUser {
            return try BKTUser.init(with: self)
        }
    }
}

extension BKTUser {
    @available(*, deprecated, message: "Use the Builder class instead. Check the documentation for more information.")
    public init(
        id: String,
        attributes: [String: String] = [:]
    ) throws {
        guard !id.isEmpty else {
            throw BKTError.illegalArgument(message: "The user id is required.")
        }
        self = BKTUser(id: id, attr: attributes)
    }

    private init(with builder: Builder) throws {
        guard let userId = builder.id, !userId.isEmpty else {
            throw BKTError.illegalArgument(message: "The user id is required.")
        }
        self = BKTUser(id: userId, attr: builder.attributes)
    }
}
