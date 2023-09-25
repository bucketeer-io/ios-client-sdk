import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class EvaluationStorageTests: XCTestCase {
    func testGetByUserId() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao(getHandler: { userId in
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
        XCTAssertEqual(expected, try? storage.get(userId: testUserId1))
        wait(for: [expectation], timeout: 0.1)
    }

    func testGetByUserIdAndFeatureId() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao(getHandler: { userId in
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
        let expected = storage.getBy(userId: testUserId1, featureId: Evaluation.mock2.featureId)
        XCTAssertEqual(expected, .mock2)
        wait(for: [expectation], timeout: 0.1)
    }

    func testDeleteAllAndInsert() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
        expectation.expectedFulfillmentCount = 4
        expectation.assertForOverFulfill = true
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao(putHandler: { userId, evaluations in
            // 2. put new data
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
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
        try storage.deleteAllAndInsert(userId: testUserId1, evaluations: [.mock1, .mock2], evaluatedAt: "1024")
        let expected = try storage.get(userId: testUserId1)
        XCTAssertEqual(expected, [.mock1, .mock2])
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        wait(for: [expectation], timeout: 0.1)
    }

    func testUpdate() throws {
        let expectation = XCTestExpectation(description: "testGetByUserId")
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
        let mockDao = MockEvaluationDao(putHandler: { userId, evaluations in
            expectation.fulfill()
            XCTAssertEqual(testUserId1, userId)
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
            evaluations: [mockEvaluationForUpsert, mockEvaluationForInsert],
            archivedFeatureIds: [
                Evaluation.mock1.featureId
            ],
            evaluatedAt: "1024"
        )
        XCTAssertTrue(result, "update action should success")
        XCTAssertEqual(storage.evaluatedAt, "1024", "evaluatedAt should be 1024")
        XCTAssertEqual(
            Set(try storage.get(userId: testUserId1)),
            Set([mockEvaluationForUpsert, mockEvaluationForInsert]),
            "expected [mock2Updated, mockEvaluationForInsert] in the database"
        )
        wait(for: [expectation], timeout: 0.1)
    }

    func testGetStorageValues() throws {
        let testUserId1 = Evaluation.mock1.userId
        let mockDao = MockEvaluationDao()
        let mockUserDefsDao = MockEvaluationUserDefaultsDao()
        let storage = EvaluationStorageImpl(
            userId: testUserId1,
            evaluationDao: mockDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: mockUserDefsDao
        )

        XCTAssertEqual(storage.evaluatedAt, "0", "should = 0")
        XCTAssertEqual(storage.currentEvaluationsId, "")
        XCTAssertFalse(storage.userAttributesUpdated)
        XCTAssertEqual(storage.featureTag, "")

        storage.currentEvaluationsId = "evaluationIdForTest"
        storage.userAttributesUpdated = true
        storage.featureTag = "featureTagForTest"
        let result = try storage.update(evaluations: [.mock2], archivedFeatureIds: [Evaluation.mock1.featureId], evaluatedAt: "1024")
        XCTAssertTrue(result, "update action should success")
        XCTAssertEqual(storage.evaluatedAt, "1024", "should save last evaluatedAt")
        XCTAssertEqual(storage.currentEvaluationsId, "evaluationIdForTest")
        XCTAssertTrue(storage.userAttributesUpdated)
        XCTAssertEqual(storage.featureTag, "featureTagForTest")
    }
}
