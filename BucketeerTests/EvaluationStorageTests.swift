import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class EvaluationStorageTests: XCTestCase {
    func testGetByUserId() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationSQLDao(getHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            if userId == testUserId1 {
                return [ .mock1, .mock2]
            }
            return []
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let cacheDao = EvaluationMemCacheDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: cacheDao,
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        // Check cache
        let expected : [Evaluation] = [.mock1, .mock2]
        XCTAssertEqual(expected, cacheDao.get(key: testUserId1))
        XCTAssertEqual(expected, try? storage.get())
        wait(for: [expectation], timeout: 0.1)
    }

    func testGetByFeatureId() throws {
        let expectation = XCTestExpectation(description: "testGetByFeatureId")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationSQLDao(getHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            if userId == testUserId1 {
                return [ .mock1, .mock2]
            }
            return []
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        // Should return first evaluation has `feature_id` == Evaluation.mock2.featureId
        let expected = storage.getBy(featureId: Evaluation.mock2.featureId)
        XCTAssertEqual(expected, .mock2)
        wait(for: [expectation], timeout: 0.1)
    }

    func testDeleteAllAndInsert() throws {
        let expectation = XCTestExpectation(description: "testDeleteAllAndInsert")
        expectation.expectedFulfillmentCount = 4
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationSQLDao(putHandler: { evaluations in
            // 2. put new data
            expectation.fulfill()
            evaluations.forEach { evaluation in
                XCTAssertEqual(evaluation.userId, testUserId1)
            }
            XCTAssertEqual(evaluations, [.mock1, .mock2])
        }, getHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            if userId == testUserId1 {
                return [ .mock1, .mock2]
            }
            return []
        }, deleteAllHandler: { userId in
            // 1. delete all
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
        }, deleteByIdsHandlder: { _ in
            XCTFail("should not called")
        }, startTransactionHandler: { block in
            // Should use use transaction
            try block()
            expectation.fulfill()
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        try storage.deleteAllAndInsert(evaluationId:"evaluationId_1", evaluations: [.mock1, .mock2], evaluatedAt: "1024")
        let expected = try storage.get()
        XCTAssertEqual(expected, [.mock1, .mock2])
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        XCTAssertEqual(storage.currentEvaluationsId, "evaluationId_1")
        wait(for: [expectation], timeout: 0.1)
    }

    func testUpdate() throws {
        let expectation = XCTestExpectation(description: "testUpdate")
        expectation.expectedFulfillmentCount = 5
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock2.userId
        // This is a mock data for ensure we fixed a bug which explained here
        // https://github.com/bucketeer-io/android-client-sdk/pull/88#discussion_r1333847962
        let mockEvaluationForUpsert = Evaluation(
            // The upsert logic will use the feature flag id rather than the evaluation_id
            // Because the evaluation_id is based on the feature version.
            // Every time a flag changes, the version number is incremented.
            // See Evaluation.mock2
            id: "feature2:2:user1",
            featureId: "feature2",
            featureVersion: 2,
            userId: User.mock1.id,
            variationId: "variation2_updated",
            variationName: "variation name2 updated",
            variationValue: "2",
            reason: .init(
                type: .rule,
                ruleId: "rule2"
            )
        )
        let mockEvaluationForInsert = Evaluation(
            id: "feature8:1:user1",
            featureId: "feature8",
            featureVersion: 1,
            userId: User.mock1.id,
            variationId: "variation10",
            variationName: "variation name10",
            variationValue: "19",
            reason: .init(
                type: .rule,
                ruleId: "rule2"
            )
        )
        var getHandlerAccessCount = 0
        let mockDao = MockEvaluationSQLDao(putHandler: { evaluations in
            expectation.fulfill()
            evaluations.forEach { evaluation in
                XCTAssertEqual(evaluation.userId, testUserId1)
            }
            XCTAssertEqual(Set(evaluations), Set([mockEvaluationForUpsert, mockEvaluationForInsert]))
        }, getHandler: { userId in
            // Should fullfill 2 times
            // 1 for init cache
            // 2 for prepare for update by loading the valid data from database
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
            defer {
                getHandlerAccessCount+=1
            }
            switch getHandlerAccessCount {
            case 0 :
                if userId == testUserId1 {
                    // From the first time in the database has 2 items
                    // This is expected call for refreshing the evaluation in-memory cache
                    return [ .mock1, .mock2]
                }
            case 1 :
                if userId == testUserId1 {
                    // This is expected call for checking the current evaluations in the database before update
                    return [.mock1, .mock2]
                }
            // Finally, we should expected [mockEvaluationForUpsert, mockEvaluationForInsert] in the database
            default: return [mockEvaluationForUpsert, mockEvaluationForInsert]
            }
            return []
        }, deleteAllHandler: { userId in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
        }, deleteByIdsHandlder: { _ in
            XCTFail("should not called")
        }, startTransactionHandler: { block in
            // Should use use transaction
            try block()
            expectation.fulfill()
        })
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )
        // Should update Evaluation.mock2, insert `mockEvaluationForInsert` & remove Evaluation.mock1
        let result = try storage.update(
            evaluationId: "evaluationId_2",
            evaluations: [mockEvaluationForUpsert, mockEvaluationForInsert],
            archivedFeatureIds: [
                Evaluation.mock1.featureId
            ],
            evaluatedAt: "1024"
        )
        XCTAssertTrue(result, "update action should success")
        XCTAssertEqual(storage.evaluatedAt, "1024", "evaluatedAt should be 1024")
        XCTAssertEqual(
            Set(try storage.get()),
            Set([mockEvaluationForUpsert, mockEvaluationForInsert]),
            "expected [mock2Updated, mockEvaluationForInsert] in the database"
        )
        XCTAssertEqual(storage.currentEvaluationsId, "evaluationId_2")
        wait(for: [expectation], timeout: 0.1)
    }

    func testGetStorageValues() throws {
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationSQLDao()
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )

        XCTAssertEqual(storage.evaluatedAt, "0", "should = 0")
        XCTAssertEqual(storage.currentEvaluationsId, "")
        XCTAssertFalse(storage.userAttributesState.isUpdated)
        XCTAssertEqual(storage.featureTag, "")

        storage.setUserAttributesUpdated()

        let userAttributesState = storage.userAttributesState
        let updatedVersion = userAttributesState.version
        storage.setFeatureTag(value: "featureTagForTest")

        let result = try storage.update(
            evaluationId:"evaluationIdForTest",
            evaluations: [.mock2],
            archivedFeatureIds: [Evaluation.mock1.featureId],
            evaluatedAt: "1024"
        )
        XCTAssertTrue(result, "update action should success")
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        XCTAssertEqual(storage.currentEvaluationsId, "evaluationIdForTest")
        XCTAssertTrue(storage.userAttributesState.isUpdated)
        XCTAssertEqual(storage.featureTag, "featureTagForTest")

        XCTAssertTrue(storage.clearUserAttributesUpdated(state: userAttributesState))
        XCTAssertFalse(storage.userAttributesState.isUpdated)
    }

    func testShouldOnlyClearUserAttributesUpdatedWhenVersionMatches() throws {
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationSQLDao()
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )

        XCTAssertFalse(storage.userAttributesState.isUpdated)

        storage.setUserAttributesUpdated()
        let firstState = storage.userAttributesState
        XCTAssertTrue(firstState.isUpdated)
        XCTAssertEqual(firstState.version, 1)

        storage.setUserAttributesUpdated()
        let finalState = storage.userAttributesState

        XCTAssertTrue(finalState.isUpdated)
        XCTAssertEqual(finalState.version, 2)

        // Attempt to clear with an incorrect version
        XCTAssertFalse(storage.clearUserAttributesUpdated(state: firstState))
        XCTAssertTrue(storage.userAttributesState.isUpdated, "userAttributesUpdated should remain true when version does not match")

        // Now clear with the correct version
        XCTAssertTrue(storage.clearUserAttributesUpdated(state: finalState))
        XCTAssertFalse(storage.userAttributesState.isUpdated, "userAttributesUpdated should be false after clearing with correct version")
    }

    func testSetUserAttributesUpdatedConcurrency() {
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationSQLDao()
        // Use `EvaluationUserDefaultDaoImpl` because it serializes access to `UserDefaults.standard` with an internal lock,
        // giving a realistic, thread-safe backing store for concurrent reads/writes.
        // The test concurrently performs user updates and SDK reads/clears; with correct locking the version counter
        // must equal the number of updates and the final `userAttributesUpdated` flag should be `false` after all clears.
        let mockUserDefsDao = EvaluationUserDefaultDaoImpl(defaults: UserDefaults.standard)
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )

        let iterations = 10000
        let group = DispatchGroup()

        // Simulating the Main Thread (UI events triggering updates)
        let mainQueue = DispatchQueue(label: "io.bucketeer.test.main")

        // Simulating the SDK Queue (Network callbacks triggering clears)
        let sdkQueue = DispatchQueue(label: "io.bucketeer.test.sdk")

        for _ in 0..<iterations {
            group.enter()
            sdkQueue.async {
                // Simulate SDK reading version for a fetch (Read)
                let userAttributesState = storage.userAttributesState
                // Simulate SDK clearing after fetch (Read/Write)
                storage.clearUserAttributesUpdated(state: userAttributesState)
                group.leave()
            }

            group.enter()
            mainQueue.async {
                // Simulate User updating attributes (Write)
                storage.setUserAttributesUpdated()
                group.leave()
            }
        }

        // Wait for all operations to complete
        let result = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(result, .success, "Test timed out")
        // Due to the inherent race between concurrent "update" and "clear" operations, the final value of
        // `userAttributesUpdated` can legitimately be either true or false. This test therefore only asserts
        // that the version counter matches the number of update calls, proving there are no race conditions
        // when incrementing the version.
        let userAttributesState = storage.userAttributesState
        XCTAssertEqual(userAttributesState.version, iterations, "Version should exactly match the number of update calls, proving no race conditions")
    }
}
