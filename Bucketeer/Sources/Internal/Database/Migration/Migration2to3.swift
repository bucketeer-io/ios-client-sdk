final class Migration2to3: Migration {
    private let db: SQLite

    init(db: SQLite) {
        self.db = db
    }

    func migration() throws {
        try db.exec(query: "DELETE FROM Evaluations")
    }
}
