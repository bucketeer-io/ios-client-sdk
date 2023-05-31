import Foundation

extension SQLite {
    enum Condition {
        case equal(column: String, value: Any)
        case `in`(column: String, values: [Any])
        case notin(column: String, values: [Any])

        var sql: String {
            switch self {
            case .equal(let column, let value):
                return "\(column) = \"\(value)\""
            case .in(let column, let values):
                let textValues = values.map({ "\"\($0)\""}).joined(separator: ", ")
                return "\(column) IN (\(textValues))"
            case .notin(let column, let values):
                let textValues = values.map({ "\"\($0)\""}).joined(separator: ", ")
                return "\(column) NOT IN (\(textValues))"
            }
        }
    }
}
