import Foundation

protocol SQLiteValue {
    static var valueType: String { get }
}

extension Int: SQLiteValue {
    static var valueType: String { "INTEGER" }
}

extension Int32: SQLiteValue {
    static var valueType: String { "INTEGER" }
}

extension Int64: SQLiteValue {
    static var valueType: String { "INTEGER" }
}

extension String: SQLiteValue {
    static var valueType: String { "TEXT" }
}

extension Data: SQLiteValue {
    static var valueType: String { "BLOB" }
}
