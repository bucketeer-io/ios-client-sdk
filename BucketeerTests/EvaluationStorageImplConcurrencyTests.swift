import XCTest
@testable import Bucketeer

final class EvaluationStorageImplConcurrencyTests: XCTestCase {
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

    // Test 1: Integration test - Thread-safety for concurrent read/write access
    func testConcurrentReadAndWriteSafety() throws {
        let db = try SQLite(path: path, logger: nil)
        let storage = EvaluationStorageImpl(
            userId: "test_user_id",
            evaluationDao: EvaluationSQLDaoImpl(db: db),
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: EvaluationUserDefaultDaoImpl(defaults: UserDefaults.standard)
        )

        let expectation = self.expectation(description: "Concurrent read/write operations should complete without crashing")
        expectation.expectedFulfillmentCount = 2

        let iterations = 1000
        let writeQueue = DispatchQueue(label: "io.bucketeer.sdk.queue", qos: .userInitiated)
        let readQueue = DispatchQueue(label: "main.queue.simulation", qos: .userInteractive)

        writeQueue.async {
            for i in 0..<iterations {
                try? storage.deleteAllAndInsert(
                    evaluationId: "eval_id_\(i)",
                    evaluations: [],
                    evaluatedAt: "\(Date().timeIntervalSince1970)"
                )
            }
            expectation.fulfill()
        }

        readQueue.async {
            for _ in 0..<iterations {
                _ = storage.getBy(featureId: "target_feature_id")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0, handler: nil)
    }

    // Test 2: Atomicity of compound operations (SQL + UserDefaults + Cache)
//    func testAtomicityOfCompoundOperations() {
//        let blockingSQLDao = BlockingMockSQLDao()
//        let memCacheDao = MockEvaluationMemCacheDao()
//        let userDefaultsDao = MockEvaluationUserDefaultsDao()
//
//        let storage = EvaluationStorageImpl(
//            userId: "test_user",
//            evaluationDao: blockingSQLDao,
//            evaluationMemCacheDao: memCacheDao,
//            evaluationUserDefaultsDao: userDefaultsDao
//        )
//
//        let oldEval = Evaluation.mock(id: "old_eval", featureId: "target_feature", value: "old_value")
//        memCacheDao.set(key: "test_user", value: [oldEval])
//        let newEval = Evaluation.mock(id: "new_eval", featureId: "target_feature", value: "new_value")
//
//        let writeStartedExpectation = expectation(description: "Write operation started and acquired lock")
//        let writeFinishedExpectation = expectation(description: "Write operation finished")
//        let readFinishedExpectation = expectation(description: "Read operation finished")
//        let continueWriteExpectation = XCTestExpectation(description: "Signal to continue write")
//
//        blockingSQLDao.onStartTransaction = {
//            writeStartedExpectation.fulfill()
//            let result = XCTWaiter.wait(for: [continueWriteExpectation], timeout: 2.0)
//            if result != .completed { print("Test timed out waiting for signal") }
//        }
//
//        let writeQueue = DispatchQueue(label: "io.bucketeer.write")
//        let readQueue = DispatchQueue(label: "io.bucketeer.read")
//
//        writeQueue.async {
//            try? storage.deleteAllAndInsert(
//                evaluationId: "new_id",
//                evaluations: [newEval],
//                evaluatedAt: "12345"
//            )
//            writeFinishedExpectation.fulfill()
//        }
//
//        wait(for: [writeStartedExpectation], timeout: 1.0)
//
//        var readResult: Evaluation?
//        readQueue.async {
//            readResult = storage.getBy(featureId: "target_feature")
//            readFinishedExpectation.fulfill()
//        }
//
//        usleep(50_000)
//        continueWriteExpectation.fulfill()
//        wait(for: [writeFinishedExpectation, readFinishedExpectation], timeout: 1.0)
//
//        XCTAssertEqual(readResult?.id, "new_eval", "Read operation should have been blocked until Write completed, ensuring no stale data was read.")
//        XCTAssertEqual(memCacheDao.get(key: "test_user")?.first?.id, "new_eval", "Cache should be finally updated")
//    }
}

/*
// MARK: - Mocks

private class MockEvaluationSQLDao: EvaluationSQLDao {
    func startTransaction(block: () throws -> Void) throws { try block() }
    func deleteAll(userId: String) throws {}
    func put(evaluations: [Evaluation]) throws {}
    func get(userId: String) throws -> [Evaluation] { return [] }
}

private class MockEvaluationMemCacheDao: EvaluationMemCacheDao {
    private var cache: [String: [Evaluation]] = [:]
    func get(key: String) -> [Evaluation]? { cache[key] }
    func set(key: String, value: [Evaluation]) { cache[key] = value }
}

private class MockEvaluationUserDefaultsDao: EvaluationUserDefaultsDao {
    var currentEvaluationsId: String = ""
    var featureTag: String = ""
    var evaluatedAt: String = ""
    var userAttributesUpdated: Bool = false
    func setCurrentEvaluationsId(value: String) { currentEvaluationsId = value }
    func setFeatureTag(value: String) { featureTag = value }
    func setEvaluatedAt(value: String) { evaluatedAt = value }
    func setUserAttributesUpdated(value: Bool) { userAttributesUpdated = value }
}

private class BlockingMockSQLDao: EvaluationSQLDao {
    var onStartTransaction: (() -> Void)?
    func startTransaction(block: () throws -> Void) throws {
        onStartTransaction?()
        try block()
    }
    func deleteAll(userId: String) throws {}
    func put(evaluations: [Evaluation]) throws {}
    func get(userId: String) throws -> [Evaluation] { return [] }
}

private extension Evaluation {
    static func mock(id: String, featureId: String, value: String) -> Evaluation {
        return Evaluation(
            id: id,
            featureId: featureId,
            featureVersion: 1,
            userId: "test_user",
            variationId: "var_id",
            variationName: "var_name",
            variationValue: value,
            reason: .init(type: .default),
            maintained: true
        )
    }
}
*/
