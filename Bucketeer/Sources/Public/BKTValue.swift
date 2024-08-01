import Foundation

/**
 * BKTValue Represents a JSON node value
 */
public enum BKTValue: Equatable, Codable, Hashable {
    case boolean(Bool)
    case string(String)
    case integer(Int64)
    case double(Double)
    case list([BKTValue])
    case dictionary([String: BKTValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int64.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let objectValue = try? container.decode([String: BKTValue].self) {
            self = .dictionary(objectValue)
        } else if let arrayValue = try? container.decode([BKTValue].self) {
            self = .list(arrayValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode BKTValue")
        }
    }

    // Encode the JSON based on its type
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .list(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public static func of<T>(_ value: T) -> BKTValue {
        if let value = value as? Bool {
            return .boolean(value)
        } else if let value = value as? String {
            return .string(value)
        } else if let value = value as? Int64 {
            return .integer(value)
        } else if let value = value as? Double {
            return .double(value)
        } else {
            return .null
        }
    }

    public func getTyped<T>() -> T? {
        if let value = self as? T {
            return value
        }

        switch self {
        case .boolean(let value): return value as? T
        case .string(let value): return value as? T
        case .integer(let value): return value as? T
        case .double(let value): return value as? T
        case .list(let value): return value as? T
        case .dictionary(let value): return value as? T
        case .null: return nil
        }
    }

    public func asBoolean() -> Bool? {
        if case let .boolean(bool) = self {
            return bool
        }

        return nil
    }

    public func asString() -> String? {
        if case let .string(string) = self {
            return string
        }

        return nil
    }

    public func asInteger() -> Int64? {
        if case let .integer(int64) = self {
            return int64
        }

        return nil
    }

    public func asDouble() -> Double? {
        if case let .double(double) = self {
            return double
        }

        return nil
    }

    public func asList() -> [BKTValue]? {
        if case let .list(values) = self {
            return values
        }

        return nil
    }

    public func asDictionary() -> [String: BKTValue]? {
        if case let .dictionary(values) = self {
            return values
        }

        return nil
    }
}

extension BKTValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .boolean(let value):
            return "\(value)"
        case .string(let value):
            return value
        case .integer(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .list(value: let values):
            return "\(values.map { value in value.description })"
        case .dictionary(value: let values):
            return "\(values.mapValues { value in value.description })"
        case .null:
            return "null"
        }
    }
}

extension BKTValue {
    public func decode<T: Decodable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: toJson(value: self))
        return try JSONDecoder().decode(T.self, from: data)
    }

    func toJson(value: BKTValue) -> Any {
        switch value {
        case .boolean(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let int64):
            return int64
        case .double(let double):
            return double
        case .list(let list):
            return list.map(self.toJson)
        case .dictionary(let structure):
            return structure.mapValues(self.toJson)
        case .null:
            return NSNull()
        }
    }
}
