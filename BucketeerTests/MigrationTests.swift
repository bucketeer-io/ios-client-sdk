import XCTest
@testable import Bucketeer

@available(iOS 13, *)
class MigrationTests: XCTestCase {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.db")
    var path: String { url.path }

    override func setUp() async throws {
        try await super.setUp()

        let db = try SQLite(path: path, logger: nil)
        try db.exec(query: currentEvaluationSQL)
        try db.exec(query: latestEvaluationSQL)
        try db.exec(query: eventSQL)
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: url)

        try await super.tearDown()
    }

    func testMigration1to2() throws {
        let db = try SQLite(path: path, logger: nil)
        try Migration1to2(db: db).migration()

        let sql = """
SELECT name, sql FROM sqlite_master
WHERE type = 'table'
AND (name NOT LIKE 'sqlite_%' AND name NOT LIKE 'ios_%')
"""
        let statement = try db.prepareStatement(sql: sql)

        var tables = ["Events", "Evaluations"]
        while (try statement.step()) {
            let name = statement.string(at: 0)
            switch name {
            case "Events":
                tables.removeAll(where: { $0 == "Events" })
            case "Evaluations":
                tables.removeAll(where: { $0 == "Evaluations" })
            default:
                XCTFail("unexpected table \(name)")
            }
        }
        try statement.reset()
        try statement.finalize()
        XCTAssertEqual(tables.isEmpty, true)
    }

    func testMigration2to3() throws {
        let db = try SQLite(path: path, logger: nil)
        try Migration1to2(db: db).migration()
        // Insert some data to database
        let dao = EvaluationDaoImpl.init(db: db)
        let mocks: [Evaluation] = [
            .mock1
        ]
        try dao.put(userId: "user1", evaluations: mocks)
        // Run migrate , it will delete all data from `evaluations` table
        try Migration2to3(db: db).migration()
        let sql = """
SELECT id FROM Evaluations
"""
        let statement = try db.prepareStatement(sql: sql)
        var resultCount = 0
        while (try statement.step()) {
            resultCount+=1
        }
        try statement.reset()
        try statement.finalize()
        // Should empty
        XCTAssertEqual(resultCount, 0)
    }
}

private let currentEvaluationSQL = """
CREATE TABLE current_evaluation (
    user_id TEXT NOT NULL,
    feature_id TEXT NOT NULL,
    evaluation BLOB NOT NULL,
    PRIMARY KEY(
     user_id,
     feature_id
    )
)
"""

private let latestEvaluationSQL = """
CREATE TABLE latest_evaluation (
   user_id TEXT,
   feature_id TEXT,
   evaluation BLOB,
   PRIMARY KEY(
     user_id,
     feature_id
   )
)
"""

private let eventSQL = """
CREATE TABLE event (
   id TEXT PRIMARY KEY,
   event BLOB
)
"""
