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

    // Verifies that read operations remain non-blocking during active write transactions.
    // This test asserts that the system returns existing (stale) data immediately instead of blocking the calling thread (e.g., the main thread) while waiting for a database update.
    // This behavior prioritizes application responsiveness and prevents UI freezes, accepting momentary data staleness during background updates.
    func testReadPerformanceDuringWrite() throws {
        let db = try SQLite(path: path, logger: nil)

        // 1. Setup Wrapper around Real DAO
        let blockingSQLDao = BlockingRealSQLDao(db: db)

        // Use Real Cache
        let memCacheDao = EvaluationMemCacheDao()

        // Use Real UserDefaults with a specific suite
        let userDefaults = UserDefaults(suiteName: "EvaluationStorageImplConcurrencyTests")!
        userDefaults.removePersistentDomain(forName: "EvaluationStorageImplConcurrencyTests")
        let userDefaultsDao = EvaluationUserDefaultDaoImpl(defaults: userDefaults)

        // Use mock user ID from MockEvaluations
        let userId = User.mock1.id
        let storage = EvaluationStorageImpl(
            userId: userId,
            evaluationDao: blockingSQLDao,
            evaluationMemCacheDao: memCacheDao,
            evaluationUserDefaultsDao: userDefaultsDao
        )

        // 2. Initial State: Populate with "OLD" data (mock1)
        let oldEval = Evaluation.mock1
        try storage.deleteAllAndInsert(evaluationId: "init_id", evaluations: [oldEval], evaluatedAt: "0")

        // Verify initial state
        XCTAssertEqual(storage.getBy(featureId: oldEval.featureId)?.id, oldEval.id)

        // 3. Prepare "NEW" data (mock1Updated)
        let newEval = Evaluation.mock1Updated

        // 4. Expectations
        let writeStartedExpectation = expectation(description: "Write operation started and acquired write lock")
        let writeFinishedExpectation = expectation(description: "Write operation finished")
        let readFinishedExpectation = expectation(description: "Read operation finished")
        let continueWriteExpectation = XCTestExpectation(description: "Signal to continue write")

        // Configure Wrapper to pause inside the transaction
        blockingSQLDao.onStartTransaction = {
            writeStartedExpectation.fulfill()
        }
        blockingSQLDao.continueWriteExpectation = continueWriteExpectation

        let writeQueue = DispatchQueue(label: "io.bucketeer.write")
        let readQueue = DispatchQueue(label: "io.bucketeer.read")

        // 5. Start Write Operation (Queue A)
        writeQueue.async {
            // This will acquire the write lock, start transaction, and then BLOCK inside the wrapper.
            try? storage.deleteAllAndInsert(
                evaluationId: "new_id",
                evaluations: [newEval],
                evaluatedAt: "12345"
            )
            writeFinishedExpectation.fulfill()
        }

        // Wait for Write to acquire the lock and enter transaction
        wait(for: [writeStartedExpectation], timeout: 2.0)

        // 6. Start Read Operation (Queue B)
        var readResult: Evaluation?
        readQueue.async {
            // With the "Two Locks" strategy, this should NOT block on the write lock.
            // It should acquire the cache lock (which is free) and return the current (old) value immediately.
            readResult = storage.getBy(featureId: newEval.featureId)
            readFinishedExpectation.fulfill()
        }

        // 7. Verify Read finishes BEFORE Write finishes
        // We wait for read to finish while write is still paused.
        wait(for: [readFinishedExpectation], timeout: 1.0)

        // Assert we got the OLD value (Stale Read)
        XCTAssertEqual(readResult?.id, oldEval.id, "Read operation should proceed immediately returning stale data, avoiding UI blocking.")

        // 8. Finish the Write
        continueWriteExpectation.fulfill()
        wait(for: [writeFinishedExpectation], timeout: 1.0)

        // 9. Verify Final State
        XCTAssertEqual(storage.getBy(featureId: newEval.featureId)?.id, newEval.id, "Cache should be finally updated after write completes")
    }

    // MARK: - Helpers

    private func createMockEvaluation(id: String, featureId: String, value: String, userId: String) -> Evaluation {
        return Evaluation(
            id: id,
            featureId: featureId,
            featureVersion: 1,
            userId: userId,
            variationId: "var_id",
            variationName: "var_name",
            variationValue: value,
            reason: .init(type: .default)
        )
    }
}

/// A wrapper around the real EvaluationSQLDaoImpl that allows pausing inside a transaction
private class BlockingRealSQLDao: EvaluationSQLDao {

    private let realDao: EvaluationSQLDaoImpl
    var onStartTransaction: (() -> Void)?
    var continueWriteExpectation: XCTestExpectation?

    init(db: SQLite) {
        self.realDao = EvaluationSQLDaoImpl(db: db)
    }

    func startTransaction(block: () throws -> Void) throws {
        onStartTransaction?()
        try realDao.startTransaction {
            // Execute the actual storage logic (SQL delete/insert)
            try block()

            // Pause here! We are now inside the transaction and holding the Storage lock.
            // This simulates the time window where SQL is updated but Cache is not yet updated.
            if let expectation = continueWriteExpectation {
                _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            }
        }
    }

    // Forward other calls to the real implementation
    func deleteAll(userId: String) throws { try realDao.deleteAll(userId: userId) }
    func deleteByIds(_ ids: [String]) throws { try realDao.deleteByIds(ids) }
    func put(evaluations: [Evaluation]) throws { try realDao.put(evaluations: evaluations) }
    func get(userId: String) throws -> [Evaluation] { return try realDao.get(userId: userId) }
}
