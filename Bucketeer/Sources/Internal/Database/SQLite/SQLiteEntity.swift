import Foundation

protocol SQLiteEntity {
    associatedtype Model: Codable

    static var tableName: String { get }

    static func model(from statement: SQLite.Statement) throws -> Model
}
