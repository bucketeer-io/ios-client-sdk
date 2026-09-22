import XCTest
@testable import Bucketeer

/// Covers the stale-write guard in `EvaluationStorageImpl`: a write whose incoming
/// `evaluatedAt` is strictly older than what is already stored must be skipped, not
/// applied. This guards the race where a slow poll response lands after fresher
/// streamed data and rewinds the cache.
///
/// A separate file from `EvaluationStorageTests`, which is already close to
/// SwiftLint's `file_length`/`type_body_length` limits under `swiftlint --strict`.
@available(iOS 13, *)
final class EvaluationStorageStaleWriteTests: XCTestCase {

    /// Builds storage prefilled with `storedEvaluatedAt`, backed by `sqlDao` so tests
    /// can assert exactly which SQL calls did or did not happen.
    private func makeStorage(
        storedEvaluatedAt: String,
        sqlDao: MockEvaluationSQLDao
    ) -> EvaluationStorageImpl {
        let userDefsDao = MockEvaluationUserDefaultsDao()
        userDefsDao.evaluatedAt = storedEvaluatedAt
        return EvaluationStorageImpl(
            userId: Evaluation.mock1.userId,
            evaluationDao: sqlDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: userDefsDao
        )
    }

    func testDeleteAllAndInsertSkipsStaleWrite() throws {
        let sqlDao = MockEvaluationSQLDao(
            putHandler: { _ in XCTFail("should not write: incoming evaluatedAt is older") },
            getHandler: { _ in [] },
            deleteAllHandler: { _ in XCTFail("should not write: incoming evaluatedAt is older") },
            startTransactionHandler: { _ in XCTFail("should not open a transaction for a stale write") }
        )
        let storage = makeStorage(storedEvaluatedAt: "1024", sqlDao: sqlDao)

        let result = try storage.deleteAllAndInsert(
            evaluationId: "should_not_apply",
            evaluations: [.mock1],
            evaluatedAt: "1023")

        XCTAssertFalse(result, "a strictly older evaluatedAt must be rejected")
        XCTAssertEqual(storage.evaluatedAt, "1024", "stored evaluatedAt must be untouched")
        XCTAssertEqual(storage.currentEvaluationsId, "", "stored id must be untouched")
        XCTAssertEqual(try storage.get(), [], "cache must be untouched")
    }

    func testDeleteAllAndInsertAllowsEqualEvaluatedAt() throws {
        let expectation = XCTestExpectation(description: "write happens")
        expectation.expectedFulfillmentCount = 3
        let sqlDao = MockEvaluationSQLDao(
            putHandler: { _ in expectation.fulfill() },
            getHandler: { _ in [] },
            deleteAllHandler: { _ in expectation.fulfill() },
            startTransactionHandler: { block in
                try block()
                expectation.fulfill()
            }
        )
        let storage = makeStorage(storedEvaluatedAt: "1024", sqlDao: sqlDao)

        let result = try storage.deleteAllAndInsert(
            evaluationId: "evaluations_id_2",
            evaluations: [.mock1],
            evaluatedAt: "1024")

        XCTAssertTrue(result, "an equal evaluatedAt must still apply: same-tick writes are not stale relative to each other")
        XCTAssertEqual(storage.currentEvaluationsId, "evaluations_id_2")
        wait(for: [expectation], timeout: 0.1)
    }

    func testUpdateSkipsStaleWrite() throws {
        var getCallCount = 0
        let sqlDao = MockEvaluationSQLDao(
            putHandler: { _ in XCTFail("should not write: incoming evaluatedAt is older") },
            getHandler: { _ in
                getCallCount += 1
                return []
            },
            deleteAllHandler: { _ in XCTFail("should not write: incoming evaluatedAt is older") },
            startTransactionHandler: { _ in XCTFail("should not open a transaction for a stale write") }
        )
        let storage = makeStorage(storedEvaluatedAt: "1024", sqlDao: sqlDao)
        // The init-time refreshCache() already called get(userId:) once.
        XCTAssertEqual(getCallCount, 1)

        let result = try storage.update(
            evaluationId: "should_not_apply",
            evaluations: [.mock2],
            archivedFeatureIds: [],
            evaluatedAt: "1023")

        XCTAssertFalse(result, "a strictly older evaluatedAt must be rejected")
        XCTAssertEqual(storage.evaluatedAt, "1024")
        XCTAssertEqual(storage.currentEvaluationsId, "")
        // The guard must short-circuit BEFORE update()'s own read-current-rows step, so
        // this call must not have triggered a second get(userId:).
        XCTAssertEqual(getCallCount, 1, "update() must not read current rows before the staleness guard rejects the write")
    }

    func testUpdateAllowsEqualEvaluatedAt() throws {
        let sqlDao = MockEvaluationSQLDao(
            putHandler: nil,
            getHandler: { _ in [] },
            deleteAllHandler: nil,
            startTransactionHandler: { try $0() }
        )
        let storage = makeStorage(storedEvaluatedAt: "1024", sqlDao: sqlDao)

        let result = try storage.update(
            evaluationId: "evaluations_id_2",
            evaluations: [.mock2],
            archivedFeatureIds: [],
            evaluatedAt: "1024")

        XCTAssertTrue(result)
        XCTAssertEqual(storage.currentEvaluationsId, "evaluations_id_2")
        XCTAssertEqual(storage.evaluatedAt, "1024")
    }

    func testWriteAllowedWhenStoredEvaluatedAtIsUnreadable() throws {
        let sqlDao = MockEvaluationSQLDao(
            getHandler: { _ in [] },
            startTransactionHandler: { try $0() }
        )
        // Default stored evaluatedAt is "" (unreadable): must not block the write.
        let storage = makeStorage(storedEvaluatedAt: "", sqlDao: sqlDao)

        let result = try storage.deleteAllAndInsert(
            evaluationId: "id_1", evaluations: [.mock1], evaluatedAt: "5")

        XCTAssertTrue(result)
        XCTAssertEqual(storage.evaluatedAt, "5")
    }

    func testWriteAllowedWhenIncomingEvaluatedAtIsUnreadable() throws {
        let sqlDao = MockEvaluationSQLDao(
            getHandler: { _ in [] },
            startTransactionHandler: { try $0() }
        )
        let storage = makeStorage(storedEvaluatedAt: "1024", sqlDao: sqlDao)

        // Matches UserEvaluations.mock2 / .mockUserEvaluationsDetails, both createdAt: "".
        let result = try storage.deleteAllAndInsert(
            evaluationId: "id_1", evaluations: [.mock1], evaluatedAt: "")

        XCTAssertTrue(result, "an unreadable incoming evaluatedAt must not be treated as stale")
        XCTAssertEqual(storage.evaluatedAt, "")
    }

    func testDeleteAllAndInsertReturnsTrueWhenClearingCache() throws {
        let sqlDao = MockEvaluationSQLDao(
            getHandler: { _ in [] },
            startTransactionHandler: { try $0() }
        )
        let storage = makeStorage(storedEvaluatedAt: "1024", sqlDao: sqlDao)

        let result = try storage.deleteAllAndInsert(evaluationId: "id_1", evaluations: [], evaluatedAt: "2048")

        XCTAssertTrue(result, "a non-stale write that empties the cache still landed and must return true")
    }
}
