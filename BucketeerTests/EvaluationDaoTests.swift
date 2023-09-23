import XCTest
@testable import Bucketeer

@available(iOS 13, *)
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

    func testGetEmpty() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)
        let evaluations = try dao.get(userId: "user1")
        XCTAssertTrue(evaluations.isEmpty)
    }

    func testGetSingleItem() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)

        try dao.put(userId: "user1", evaluations: [.mock1])

        let evaluations = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations.count, 1)
        XCTAssertEqual(evaluations[0], Evaluation.mock1)
    }

    func testGetMultipleItems() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)

        try dao.put(userId: "user1", evaluations: [.mock1, .mock2])

        let evaluations = try dao.get(userId: "user1")
        XCTAssertEqual(evaluations.count, 2)
        XCTAssertEqual(evaluations[0], Evaluation.mock1)
        XCTAssertEqual(evaluations[1], Evaluation.mock2)
    }

    func testPutAsInsert() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)
        try dao.put(userId: "user1", evaluations: [
            .mock1,
            .mock2
        ])
        try dao.put(userId: "user2", evaluations: [
            .mock3
        ])

        var expectedEvaluation = try dao.get(userId: "user1")
        XCTAssertEqual(expectedEvaluation, [.mock1, .mock2])

        expectedEvaluation = try dao.get(userId: "user2")
        XCTAssertEqual(expectedEvaluation, [.mock3])
    }

    func testPutAsUpdate() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)
        try dao.put(userId: "user1", evaluations: [
            .mock1,
            .mock2
        ])
        try dao.put(userId: "user2", evaluations: [
            .mock3
        ])

        // Update
        let updatedValue = "variation - updated"
        let updatedMock = Evaluation(
            id: "feature1:1:user1",
            featureId: "feature1",
            featureVersion: 1,
            userId: User.mock1.id,
            variationId: "variation1",
            variationName: "variation name1",
            variationValue: updatedValue,
            reason: .init(
                type: .rule,
                ruleId: "rule1"
            )
        )
        try dao.put(userId: "user1", evaluations: [updatedMock])

        var expectedEvaluation = try dao.get(userId: "user1")
        XCTAssertEqual(expectedEvaluation, [.mock2, updatedMock])

        expectedEvaluation = try dao.get(userId: "user2")
        XCTAssertEqual(expectedEvaluation, [.mock3])
    }

    func testDeleteAllForUserId() throws {
        let userId1 = "user1"
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)
        try dao.put(userId: userId1, evaluations: [
            .mock1,
            .mock2
        ])

        // Put another evaluation for another user_id
        let userId2 = "user2"
        try dao.put(userId: userId2, evaluations: [
            .mock3,
            .mock4
        ])

        let evaluationsForUser1 = try dao.get(userId: userId1)
        XCTAssertEqual([.mock1, .mock2], evaluationsForUser1, "evaluations in the database did not match")
        let evaluationsForUser2 = try dao.get(userId: userId2)
        XCTAssertEqual([.mock3, .mock4], evaluationsForUser2, "evaluations in the database did not match")

        // Should delete all evaluation for userId
        try dao.deleteAll(userId: userId1)
        let shouldNotEmptyListOfEvaluations = try dao.get(userId: userId2)
        // All evaluation for `user1` should removed. On database still has evaluations for `user2`
        XCTAssertEqual(shouldNotEmptyListOfEvaluations, [.mock3, .mock4], "should not delete evaluations of other user")

        try dao.deleteAll(userId: userId2)
        let shouldEmptyListOfEvaluations = try dao.get(userId: userId2)
        XCTAssertTrue(shouldEmptyListOfEvaluations.isEmpty, "database should empty")
    }

    func testDeleteByIds() throws {
        let userId = "user1"
        let db = try SQLite(path: path, logger: nil)
        let dao = EvaluationSQLDao(db: db)
        let mocks: [Evaluation] = [
            .mock1,
            .mock2
        ]
        try dao.put(userId: userId, evaluations: mocks)

        let evaluations = try dao.get(userId: userId)
        XCTAssertEqual(mocks, evaluations, "evaluations in the database did not match")

        // Should delete all evaluation with list feature_ids
        let ids = [Evaluation.mock1.id]
        try dao.deleteByIds(ids)

        let expectedEvaluations = try dao.get(userId: userId)
        XCTAssertEqual(expectedEvaluations, [Evaluation.mock2], "expectedEvaluations should not be empty")
    }
}
