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
