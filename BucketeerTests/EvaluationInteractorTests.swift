import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length file_length
final class EvaluationInteractorTests: XCTestCase {

    func testFetchInitialLoad() {
        let testFetchInitialLoadExpectation = XCTestExpectation(description: "testFetchInitialLoad")
        testFetchInitialLoadExpectation.expectedFulfillmentCount = 6
        testFetchInitialLoadExpectation.assertForOverFulfill = true

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let evaluationCreatedAt = UserEvaluations.mock1.createdAt
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, condition, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, "")
                XCTAssertEqual(condition.evaluatedAt, "0", "evaluationCreatedAt should be `0`")
                XCTAssertEqual(condition.userAttributesUpdated, false, "userAttributesUpdated should be false")
                let response = GetEvaluationsResponse(
                    evaluations: .mock1,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                testFetchInitialLoadExpectation.fulfill()
            }
        )

        let storage = MockEvaluationStorage(updateHandler: { evaluations, archivedFeatureIds, evaluatedAt in
            testFetchInitialLoadExpectation.fulfill()
            XCTAssertEqual(evaluations, [.mock1, .mock2])
            XCTAssertEqual(archivedFeatureIds, [])
            XCTAssertEqual(evaluatedAt, UserEvaluations.mock1.createdAt)
            return true
        }, deleteAllAndInsertHandler: { _, _ in
            XCTFail("`deleteAllAndInsertHandler` should not called ")
        }, getByFeatureIdHandler: { _, featureId in
            testFetchInitialLoadExpectation.fulfill()
            if featureId == Evaluation.mock1.featureId {
                return .mock1
            }
            if featureId == Evaluation.mock2.featureId {
                return .mock2
            }
            return nil
        })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, "")

        _ = interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            // Check if listener is called if we have something new
            testFetchInitialLoadExpectation.fulfill()
        }))

        // https://github.com/bucketeer-io/android-client-sdk/issues/69
        // Save the featureTag in the UserDefault if it is configured in the BKTConfig
        XCTAssertEqual(
            config.featureTag,
            storage.featureTag,
            "featureTag should saved if it is configured in the BKTConfig"
        )
        XCTAssertEqual(
            storage.evaluatedAt,
            "0",
            "evaluatedAt should be `0`"
        )

        // We should have a new currentEvaluationsId now
        XCTAssertEqual(
            storage.currentEvaluationsId,
            "",
            "currentEvaluationsId should be empty string"
        )
        XCTAssertEqual(
            storage.userAttributesUpdated,
            false,
            "userAttributesUpdated should be false"
        )

        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.userEvaluationsId, baseUserEvaluationsId)
            case .failure(let error, _):
                XCTFail("\(error)")
            }

            XCTAssertEqual(interactor.currentEvaluationsId, baseUserEvaluationsId)
            XCTAssertEqual(interactor.getLatest(userId: User.mock1.id, featureId: Evaluation.mock1.featureId), .mock1)
            XCTAssertEqual(interactor.getLatest(userId: User.mock1.id, featureId: Evaluation.mock2.featureId), .mock2)

            testFetchInitialLoadExpectation.fulfill()
        }
        XCTAssertEqual(
            config.featureTag,
            storage.featureTag,
            "featureTag should saved if it is configured in the BKTConfig"
        )
        XCTAssertEqual(
            storage.evaluatedAt,
            evaluationCreatedAt,
            // https://github.com/bucketeer-io/android-client-sdk/issues/69
            "evaluatedAt the last time the user was evaluated. The server will return in the get_evaluations response (UserEvaluations.CreatedAt), and it must be saved in the client"
        )
        XCTAssertEqual(
            storage.currentEvaluationsId,
            baseUserEvaluationsId,
            "currentEvaluationsId should not be a empty string after fetch evaluation success"
        )
        XCTAssertEqual(
            storage.userAttributesUpdated,
            false,
            "userAttributesUpdated should be false"
        )

        wait(for: [testFetchInitialLoadExpectation], timeout: 1)
    }

    func testFetchAndUpdate() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 7
        expectation.assertForOverFulfill = true
        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let baseUserEvaluationsId_updated = baseUserEvaluationsId + "_updated"
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, _, completion in
                expectation.fulfill()
                XCTAssertEqual(user, .mock1)
                if userEvaluationsId == "" {
                    // initial request
                    let response = GetEvaluationsResponse(
                        evaluations: .mock1,
                        userEvaluationsId: baseUserEvaluationsId
                    )
                    completion?(.success(response))
                } else {
                    // second request
                    var userEvaluations = UserEvaluations.mock1
                    userEvaluations.evaluations = [.mock1Updated, .mock2]
                    userEvaluations.id = baseUserEvaluationsId_updated
                    let response = GetEvaluationsResponse(
                        evaluations: .mock1Upsert,
                        userEvaluationsId: baseUserEvaluationsId_updated
                    )
                    completion?(.success(response))
                }
            }
        )

        var updateHandlerCount = 0
        let storage = MockEvaluationStorage(updateHandler: { evaluations, archivedFeatureIds, evaluatedAt in
            if (updateHandlerCount == 0) {
                XCTAssertEqual(evaluations, [.mock1, .mock2])
                XCTAssertEqual(archivedFeatureIds, [])
                XCTAssertEqual(evaluatedAt, UserEvaluations.mock1.createdAt)
            } else if (updateHandlerCount == 1) {
                XCTAssertEqual(evaluations, [.mock1Updated, .mock2])
                XCTAssertEqual(archivedFeatureIds, [])
                XCTAssertEqual(evaluatedAt, UserEvaluations.mock1Upsert.createdAt)
            } else {
                XCTFail("should not call")
            }
            updateHandlerCount+=1
            expectation.fulfill()
            return true
        }, deleteAllAndInsertHandler: { _, _ in
            XCTFail("`deleteAllAndInsertHandler` should not called ")
        }, getByFeatureIdHandler: { _, featureId in
            expectation.fulfill()
            // Mock logic to check after 2 fetch evaluation request
            // Expectation is it should return the updated evaluation
            if featureId == Evaluation.mock1.featureId {
                // Should return .mock1Updated as mock1 has updated
                return .mock1Updated
            }
            if featureId == Evaluation.mock2.featureId {
                // Didn't changes
                return .mock2
            }
            return nil
        })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1
        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, "")
        // 1st
        interactor.fetch(user: .mock1) { _ in
            // 2nd
            interactor.fetch(user: .mock1) { result in
                switch result {
                case .success(let response):
                    XCTAssertEqual(response.userEvaluationsId, baseUserEvaluationsId_updated)
                case .failure(let error, _):
                    XCTFail("\(error)")
                }

                XCTAssertEqual(interactor.currentEvaluationsId, baseUserEvaluationsId_updated)
                XCTAssertEqual(interactor.getLatest(
                    userId: User.mock1.id,
                    featureId: "feature1"
                ), .mock1Updated)
                XCTAssertEqual(interactor.getLatest(
                    userId: User.mock1.id,
                    featureId: "feature2"
                ), Evaluation.mock2)

                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testFetchNoUpdate() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 6
        expectation.assertForOverFulfill = true

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, _, _, _, completion in
                XCTAssertEqual(user, .mock1)
                let response = GetEvaluationsResponse(
                    evaluations: .mock1,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )

        let storage = MockEvaluationStorage(updateHandler: { evaluations, archivedFeatureIds, evaluatedAt in
            XCTAssertEqual(evaluations, [.mock1, .mock2])
            XCTAssertEqual(archivedFeatureIds, [])
            XCTAssertEqual(evaluatedAt, UserEvaluations.mock1.createdAt)
            expectation.fulfill()
            return true
        }, deleteAllAndInsertHandler: { _, _ in
            XCTFail("`deleteAllAndInsertHandler` should not called ")
        }, getByFeatureIdHandler: { _, featureId in
            expectation.fulfill()
            // Mock logic to check after 2 fetch evaluation request
            // Expectation is it should return the updated evaluation
            if featureId == Evaluation.mock1.featureId {
                // Should return .mock1Updated as mock1 has updated
                return .mock1
            }
            if featureId == Evaluation.mock2.featureId {
                // Didn't changes
                return .mock2
            }
            return nil
        })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, "")
        // 1st
        interactor.fetch(user: .mock1) { _ in

            // 2nd
            interactor.fetch(user: .mock1) { result in
                switch result {
                case .success(let response):
                    XCTAssertEqual(response.userEvaluationsId, baseUserEvaluationsId)
                case .failure(let error, _):
                    XCTFail("\(error)")
                }

                XCTAssertEqual(interactor.currentEvaluationsId, baseUserEvaluationsId)
                XCTAssertEqual(interactor.getLatest(
                    userId: User.mock1.id,
                    featureId: "feature1"
                ), .mock1)
                XCTAssertEqual(interactor.getLatest(
                    userId: User.mock1.id,
                    featureId: "feature2"
                ), Evaluation.mock2)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testFetchAndFailWithDBError() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        expectation.assertForOverFulfill = true
        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, _, _, _, completion in

                XCTAssertEqual(user, .mock1)
                let response = GetEvaluationsResponse(
                    evaluations: .mock1ForceUpdate,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )

        let storage = MockEvaluationStorage(deleteAllAndInsertHandler: { _, _ in
            throw NSError(domain: "db", code: 100, userInfo: [:])
        })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, "")
        // 1st
        interactor.fetch(user: .mock1) { result in
            switch result {
            case .failure(let error, let featureTag):
                XCTAssertEqual(error, BKTError.unknown(message: "Unknown error: Error Domain=db Code=100 \"(null)\"", error: NSError(domain: "db", code: 100, userInfo: [:])))
                XCTAssertEqual(featureTag, "featureTag1")
                expectation.fulfill()
            case .success:
                XCTFail()
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testGetLatestWithCache() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 5
        expectation.assertForOverFulfill = true
        let api = MockApiClient()

        let userId1 = User.mock1.id
        let userId2 = User.mock2.id

        let storage = MockEvaluationStorage(getByFeatureIdHandler: { (userId, featureId) in
            switch userId {
            case userId1:
                expectation.fulfill()
                if (featureId == "feature1") {
                    return .mock1
                }
                if (featureId == "feature2") {
                    return .mock2
                }
                return nil
            case userId2:
                expectation.fulfill()
                if (featureId == "feature3") {
                    return .mock3
                }
                return nil
            default:
                return nil
            }
        }, refreshCacheHandler: {
            // 2 times
            expectation.fulfill()
        })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        try interactor.refreshCache()
        XCTAssertEqual(interactor.getLatest(userId: userId1, featureId: "feature1"), .mock1)
        XCTAssertEqual(interactor.getLatest(userId: userId1, featureId: "feature2"), .mock2)

        try interactor.refreshCache()
        XCTAssertEqual(interactor.getLatest(userId: userId2, featureId: "feature3"), .mock3)

        wait(for: [expectation], timeout: 1)
    }

    func testGetLatestWithoutCache() {
        let api = MockApiClient()
        let storage = MockEvaluationStorage()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1
        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.getLatest(userId: User.mock1.id, featureId: Evaluation.mock1.featureId), nil)
    }

    func testGetLatestWithoutCorrespondingEvaluation() {
        let api = MockApiClient()
        let storage = MockEvaluationStorage(getByFeatureIdHandler: { (userId, featureId) in
            switch userId {
            case User.mock1.id:
                if (featureId == "feature1") {
                    return .mock1
                }
                if (featureId == "feature2") {
                    return .mock2
                }
                return nil
            default:
                return nil
            }
        })
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1
        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.getLatest(userId: User.mock1.id, featureId: "invalid_feature_id"), nil)
    }

    func testSetEvaluationConditionWhenRequest() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        expectation.assertForOverFulfill = true

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let evaluationCreatedAt = UserEvaluations.mock1.createdAt
        let storage = MockEvaluationStorage(
            updateHandler: { _, _, _ in
                XCTFail("we should not have any update() call")
                return false
            },
            deleteAllAndInsertHandler: { _, _ in
                XCTFail("we should not have any delete() call")
            })
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1
        // Prefill state
        storage.currentEvaluationsId =  baseUserEvaluationsId
        storage.featureTag =  config.featureTag
        storage.evaluatedAt = evaluationCreatedAt
        storage.userAttributesUpdated = false
        XCTAssertEqual(storage.currentEvaluationsId, baseUserEvaluationsId)
        XCTAssertEqual(storage.featureTag, config.featureTag)
        XCTAssertEqual(storage.evaluatedAt, evaluationCreatedAt)
        XCTAssertEqual(storage.userAttributesUpdated, false)
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, condition, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, baseUserEvaluationsId)
                XCTAssertEqual(condition.evaluatedAt, evaluationCreatedAt, "evaluationCreatedAt should equal the last evaluatedAt value")
                XCTAssertEqual(condition.userAttributesUpdated, true, "userAttributesUpdated should be true")
                let response = GetEvaluationsResponse(
                    evaluations: .mock1,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, baseUserEvaluationsId)
        XCTAssertEqual(storage.currentEvaluationsId, baseUserEvaluationsId)
        XCTAssertEqual(storage.featureTag, config.featureTag)
        XCTAssertEqual(storage.evaluatedAt, evaluationCreatedAt)
        XCTAssertEqual(storage.userAttributesUpdated, false)

        interactor.setUserAttributesUpdated()
        XCTAssertEqual(storage.currentEvaluationsId, baseUserEvaluationsId)
        XCTAssertEqual(storage.featureTag, config.featureTag)
        XCTAssertEqual(storage.evaluatedAt, evaluationCreatedAt)
        XCTAssertEqual(storage.userAttributesUpdated, true)

        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.userEvaluationsId, UserEvaluations.mock1.id)
            case .failure(let error, _):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }

        // post checking
        XCTAssertEqual(storage.currentEvaluationsId, UserEvaluations.mock1.id)
        XCTAssertEqual(storage.featureTag, config.featureTag)
        XCTAssertEqual(storage.evaluatedAt, UserEvaluations.mock1.createdAt)
        // because `userAttributesUpdated` == true before fetch new evaluations, now it should be `false`
        XCTAssertEqual(storage.userAttributesUpdated, false, "userAttributesUpdated should be `false`")

        wait(for: [expectation], timeout: 1)
    }

    func testChangeFeatureTagWillClearUserEvaluationsId() {
        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient()
        let storage = MockEvaluationStorage()

        // Prefill state
        storage.currentEvaluationsId = "id_should_be_replaced"
        storage.featureTag =  "feature_tag_should_be_replaced"

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        XCTAssertEqual(storage.currentEvaluationsId, "id_should_be_replaced")
        XCTAssertEqual(storage.featureTag, "feature_tag_should_be_replaced")

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, "")
        XCTAssertEqual(storage.currentEvaluationsId, "")
        XCTAssertEqual(storage.featureTag, config.featureTag)
    }

    // https://github.com/bucketeer-io/android-client-sdk/issues/69
    // Delete all the evaluations from DB, and save the latest evaluations from the response into the DB
    func testForceUpdateEvaluations() {
        let expectation = XCTestExpectation(description: "testForceUpdateEvaluations")
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, condition, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, "")
                XCTAssertEqual(condition.evaluatedAt, "0", "evaluationCreatedAt should equal the last evaluatedAt value")
                XCTAssertEqual(condition.userAttributesUpdated, true, "userAttributesUpdated should be true")

                let response = GetEvaluationsResponse(
                    evaluations: .mock1ForceUpdate,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )
        let storage = MockEvaluationStorage(
            updateHandler: { _, _, _ in
                XCTFail("we should not have any update() call")
                return false
            },
            deleteAllAndInsertHandler: { userId, evaluations in
                XCTAssertEqual(User.mock1.id, userId)
                XCTAssertEqual(evaluations, UserEvaluations.mock1ForceUpdate.evaluations)
                expectation.fulfill()
            })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        // set `userAttributesUpdated` == true
        interactor.setUserAttributesUpdated()
        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.userEvaluationsId, baseUserEvaluationsId)
                XCTAssertEqual(response.evaluations, .mock1ForceUpdate)
                XCTAssertEqual(response.evaluations.forceUpdate, true)
                XCTAssertEqual(response.evaluations.archivedFeatureIds, [])
            case .failure(let error, _):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }

        // post checking
        XCTAssertEqual(storage.currentEvaluationsId, UserEvaluations.mock1ForceUpdate.id)
        XCTAssertEqual(storage.featureTag, config.featureTag)
        XCTAssertEqual(storage.evaluatedAt, UserEvaluations.mock1ForceUpdate.createdAt)
        // because `userAttributesUpdated` == true before fetch new evaluations, now it should be `false`
        XCTAssertEqual(storage.userAttributesUpdated, false, "userAttributesUpdated should be `false`")

        wait(for: [expectation], timeout: 0.1)
    }

    // https://github.com/bucketeer-io/android-client-sdk/issues/69
    // Check the evaluation list in the response and upsert them in the DB if the list is not empty
    // Check the list of the feature flags that were archived on the console and delete them from the DB
    func testUpsertEvaluations() {
        let expectation = XCTestExpectation(description: "testForceUpdateEvaluations")
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, condition, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, "")
                XCTAssertEqual(condition.evaluatedAt, "0", "evaluationCreatedAt should equal the last evaluatedAt value")
                XCTAssertEqual(condition.userAttributesUpdated, true, "userAttributesUpdated should be true")

                let response = GetEvaluationsResponse(
                    evaluations: .mock1UpsertAndArchivedFeature,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )
        let storage = MockEvaluationStorage(updateHandler: { evaluations, archivedFeatureIds, evaluatedAt  in
            XCTAssertEqual(evaluations, UserEvaluations.mock1UpsertAndArchivedFeature.evaluations)
            XCTAssertEqual(evaluatedAt, UserEvaluations.mock1UpsertAndArchivedFeature.createdAt)
            XCTAssertEqual(archivedFeatureIds, UserEvaluations.mock1UpsertAndArchivedFeature.archivedFeatureIds)
            expectation.fulfill()
            return true
        }, deleteAllAndInsertHandler: { _, _ in
            XCTFail("we should not have any deleteAllHandler() call")
        })

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        // set `userAttributesUpdated` == true
        interactor.setUserAttributesUpdated()
        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.evaluations.forceUpdate, false)
                XCTAssertEqual(response.evaluations.evaluations, UserEvaluations.mock1UpsertAndArchivedFeature.evaluations)
                XCTAssertEqual(response.evaluations.createdAt, UserEvaluations.mock1UpsertAndArchivedFeature.createdAt)
                XCTAssertEqual(response.evaluations.archivedFeatureIds, UserEvaluations.mock1UpsertAndArchivedFeature.archivedFeatureIds)
            case .failure(let error, _):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }

        // post checking
        XCTAssertEqual(storage.currentEvaluationsId, UserEvaluations.mock1UpsertAndArchivedFeature.id)
        XCTAssertEqual(storage.featureTag, config.featureTag)
        XCTAssertEqual(storage.evaluatedAt, UserEvaluations.mock1UpsertAndArchivedFeature.createdAt)
        // because `userAttributesUpdated` == true before fetch new evaluations, now it should be `false`
        XCTAssertEqual(storage.userAttributesUpdated, false, "userAttributesUpdated should be `false`")

        wait(for: [expectation], timeout: 0.1)
    }
}

// swiftlint:enable type_body_length file_length
