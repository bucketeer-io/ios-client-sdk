import Foundation

struct SQLiteColumn<Element: SQLiteValue>: AnySQLiteColumn {
    var value: Element
    var isPrimaryKey: Bool = false

    var anyValue: Any { value as Any }

    func sql(includesPrimaryKey: Bool) -> String {
        return "\(Element.valueType)\(includesPrimaryKey && isPrimaryKey ? " PRIMARY KEY" : "")"
    }
}
