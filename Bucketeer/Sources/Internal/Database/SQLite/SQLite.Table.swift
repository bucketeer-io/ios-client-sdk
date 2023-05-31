import Foundation

extension SQLite {
    struct Table<Entity: SQLiteEntity> {
        let columns: [(name: String, column: AnySQLiteColumn)]
        var name: String {
            Entity.tableName
        }

        init(entity: Entity) {
            self.columns = Mirror(reflecting: entity).children.compactMap { name, child -> (String, AnySQLiteColumn)? in
                guard let name = name, let column = child as? AnySQLiteColumn else {
                    return nil
                }
                return (name: name, column: column)
            }
        }

        func sqlToCreate() -> String {
            let primaryKeyColumns = columns.filter({ $0.column.isPrimaryKey })
            let hasMultiPrimaryKey = primaryKeyColumns.count > 1
            var columnsSQL = columns.map { (name, column) in
                var sql = name
                sql += " \(column.sql(includesPrimaryKey: !hasMultiPrimaryKey))"
                return sql
            }
            .joined(separator: ", ")
            if hasMultiPrimaryKey {
                let columns = primaryKeyColumns.map({ $0.name }).joined(separator: ", ")
                columnsSQL += " PRIMARY KEY(\(columns))"
            }
            return "CREATE TABLE IF NOT EXISTS \(self.name) (\(columnsSQL));"
        }

        func sqlToSelect(conditions: [SQLite.Condition]) -> String {
            guard !conditions.isEmpty else {
                return "SELECT \(columns.map(\.name).joined(separator: ", ")) FROM \(name);"
            }
            let conditionSQL = conditions.map({ $0.sql }).joined(separator: " AND ")
            return "SELECT \(columns.map(\.name).joined(separator: ", ")) FROM \(name) WHERE \(conditionSQL);"
        }

        func sqlToInsert() -> String {
            return "INSERT OR REPLACE INTO \(name) (\(columns.map(\.name).joined(separator: ", "))) VALUES (\(columns.map({ ":\($0.name)" }).joined(separator: ", ")));"
        }

        func sqlToDelete(condition: Condition) -> String {
            return "DELETE FROM \(name) WHERE \(condition.sql);"
        }
    }
}
