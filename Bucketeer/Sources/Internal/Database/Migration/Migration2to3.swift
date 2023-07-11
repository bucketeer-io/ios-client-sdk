final class Migration2to3: Migration {
    private let db: SQLite

    init(db: SQLite) {
        self.db = db
    }

    func migration() throws {
        try db.exec(query: "DROP TABLE IF EXISTS Evaluations")
        let evaluationTable = SQLite.Table(entity: EvaluationEntity())
        let evaluationSql = evaluationTable.sqlToCreate()
        try db.exec(query: evaluationSql)
    }
}
