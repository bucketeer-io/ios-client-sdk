final class EvaluationDaoImpl: EvaluationDao {
    private let db: SQLite

    init(db: SQLite) {
        self.db = db
    }

    func put(userId: String, evaluations: [Evaluation]) throws {
        let entities = try evaluations.map {
            try EvaluationEntity(model: $0)
        }
        try db.insert(entities)
    }

    func get(userId: String) throws -> [Evaluation] {
        try db.select(EvaluationEntity(), conditions: [.equal(column: "userId", value: userId)])
    }

    func deleteAllAndInsert(userId: String, evaluations: [Evaluation]) throws {
        let entities = try evaluations.map {
            try EvaluationEntity(model: $0)
        }
        try db.delete(EvaluationEntity(), condition: .equal(column: "userId", value: userId))
        try db.insert(entities)
    }
}
