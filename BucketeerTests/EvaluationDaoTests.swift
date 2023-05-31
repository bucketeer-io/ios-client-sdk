import XCTest
@testable import Bucketeer

final class EvaluationDaoTests: XCTestCase {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("evaluation_test.db")
    var path: String { url.path }

    override func setUp() async throws {
        try await super.setUp()

        let db = try SQLite(path: path, logger: nil)

        let evaluationTable = SQLite.Table(entity: EvaluationEntity())
        let evaluationSql = evaluationTable.sqlToCreate()
        try db.exec(query: evaluationSql)
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: url)

        try await super.tearDown()
    }

    func testPutAsInsert() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)
        let mocks: [Evaluation] = [
            .mock1,
            .mock2,
            .mock3
        ]
        try dao.put(userId: "user1", evaluations: mocks)

        let sql = "SELECT userId, featureId, data FROM Evaluations WHERE userId = 'user1'"
        let statement = try db.prepareStatement(sql: sql)
        let decoder = JSONDecoder()

        // Mock1
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.string(at: 0), "user1")
        XCTAssertEqual(statement.string(at: 1), "feature1")
        XCTAssertEqual(try decoder.decode(Evaluation.self, from: statement.data(at: 2)), Evaluation.mock1)

        // Mock2
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.string(at: 0), "user1")
        XCTAssertEqual(statement.string(at: 1), "feature2")
        XCTAssertEqual(try decoder.decode(Evaluation.self, from: statement.data(at: 2)), Evaluation.mock2)

        // no Mock3

        // End
        XCTAssertFalse(try statement.step())

        try statement.reset()
        try statement.finalize()
    }

    func testPutAsUpdate() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)
        let mocks: [Evaluation] = [
            .mock1
        ]
        try dao.put(userId: "user1", evaluations: mocks)

        // Update
        var updatedMock = Evaluation.mock1
        let updatedValue = "variation - updated"
        updatedMock.variation.value = updatedValue
        updatedMock.variationValue = updatedValue
        try dao.put(userId: "user1", evaluations: [updatedMock])

        let sql = "SELECT userId, featureId, data FROM Evaluations WHERE userId = 'user1'"
        let statement = try db.prepareStatement(sql: sql)
        let decoder = JSONDecoder()

        // Mock1
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.string(at: 0), "user1")
        XCTAssertEqual(statement.string(at: 1), "feature1")
        let evaluation = try decoder.decode(Evaluation.self, from: statement.data(at: 2))
        XCTAssertEqual(evaluation.variation.value, updatedValue)
        XCTAssertEqual(evaluation.variationValue, updatedValue)

        // End
        XCTAssertFalse(try statement.step())

        try statement.reset()
        try statement.finalize()
    }

    func testGetEmpty() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)
        let evaluations = try dao.get(userId: "user1")
        XCTAssertTrue(evaluations.isEmpty)
    }

    func testGetSingleItem() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)

        try dao.put(userId: "user1", evaluations: [.mock1])

        let evaluations = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations[0], Evaluation.mock1)
    }

    func testGetMultipleItems() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)

        try dao.put(userId: "user1", evaluations: [.mock1, .mock2])

        let evaluations = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations.count, 2)
        XCTAssertEqual(evaluations[0], Evaluation.mock1)
        XCTAssertEqual(evaluations[1], Evaluation.mock2)
    }

    func testDeleteAllAndInsert() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)
        try dao.deleteAllAndInsert(userId: "user1", evaluations: [.mock1])

        let evaluations = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations[0], Evaluation.mock1)
    }

    func testDeleteAllAndInsertToDeleteOldItems() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)
        try dao.deleteAllAndInsert(userId: "user1", evaluations: [.mock1])
        try dao.deleteAllAndInsert(userId: "user1", evaluations: [.mock2])

        let evaluations = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations[0], Evaluation.mock2)
    }

    func testDeleteAllAndInsertNotUpdateItemOfOtherUser() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationDaoImpl(db: db)
        try dao.deleteAllAndInsert(userId: "user1", evaluations: [.mock1])
        try dao.deleteAllAndInsert(userId: "user2", evaluations: [.mock3])

        let evaluations1 = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations1.count, 1)
        XCTAssertEqual(evaluations1[0], Evaluation.mock1)

        let evaluations2 = try dao.get(userId: "user2")
        XCTAssertEqual(evaluations2.count, 1)
        XCTAssertEqual(evaluations2[0], Evaluation.mock3)
    }
}
