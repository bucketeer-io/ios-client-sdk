import Foundation

protocol AnySQLiteColumn {
    var isPrimaryKey: Bool { get }
    var anyValue: Any { get }

    func sql(includesPrimaryKey: Bool) -> String
}
