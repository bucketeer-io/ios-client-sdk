final class EvaluationSQLDaoImpl: EvaluationSQLDao {

    private let db: SQLite

    init(db: SQLite) {
        self.db = db
    }

    func put(evaluations: [Evaluation]) throws {
        let entities = try evaluations.map {
            try EvaluationEntity(model: $0)
        }
        try db.insert(entities)
    }

    func get(userId: String) throws -> [Evaluation] {
        try db.select(EvaluationEntity(), conditions: [.equal(column: "userId", value: userId)])
    }

    func deleteAll(userId: String) throws {
        try db.delete(EvaluationEntity(), condition: .equal(column: "userId", value: userId))
    }

    func deleteByIds(_ ids: [String]) throws {
        for id in ids {
            try db.delete(EvaluationEntity(), condition: .equal(column: "id", value: id))
        }
    }

    func startTransaction(block: () throws -> Void) throws {
        try db.startTransaction {
            try block()
        }
    }
}
