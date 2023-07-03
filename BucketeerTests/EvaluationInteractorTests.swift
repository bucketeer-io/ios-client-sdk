import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length
final class EvaluationInteractorTests: XCTestCase {

    func testFetchInitialLoad() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, completion in

                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, "")

                let response = GetEvaluationsResponse(
                    evaluations: .mock1,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )

        let dao = MockEvaluationDao()
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )
        XCTAssertEqual(interactor.currentEvaluationsId, "")
        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.userEvaluationsId, baseUserEvaluationsId)
            case .failure(let error, _):
                XCTFail("\(error)")
            }

            XCTAssertEqual(interactor.currentEvaluationsId, baseUserEvaluationsId)
            XCTAssertEqual(interactor.evaluations[User.mock1.id], [.mock1, .mock2])

            let evaluation = interactor.getLatest(
                userId: User.mock1.id,
                featureId: "feature1"
            )
            XCTAssertEqual(evaluation, .mock1)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testFetchUpdate() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true

        let updatedEvaluation = Evaluation(
            id: "evaluation1_updated",
            featureId: "feature1",
            featureVersion: 1,
            userId: User.mock1.id,
            variationId: "variation1",
            variationName: "variation name1",
            variationValue: "variation_value1_updated",
            reason: .init(
                type: .rule,
                ruleId: "rule1"
            )
        )
        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let baseUserEvaluationsId_updated = baseUserEvaluationsId + "_updated"
        let api = MockApiClient(
            getEvaluationsHandler: { user, userEvaluationsId, _, completion in

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
                    userEvaluations.evaluations = [updatedEvaluation, .mock2]
                    userEvaluations.id = baseUserEvaluationsId_updated
                    let response = GetEvaluationsResponse(
                        evaluations: userEvaluations,
                        userEvaluationsId: baseUserEvaluationsId_updated
                    )
                    completion?(.success(response))
                }

                expectation.fulfill()
            }
        )

        let dao = MockEvaluationDao()
        let defaults = MockDefaults()

        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1
        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
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
                XCTAssertEqual(interactor.evaluations[User.mock1.id], [updatedEvaluation, .mock2])

                let evaluation = interactor.getLatest(
                    userId: User.mock1.id,
                    featureId: "feature1"
                )
                XCTAssertEqual(evaluation, updatedEvaluation)

                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testFetchNoUpdate() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, _, _, completion in

                XCTAssertEqual(user, .mock1)
                let response = GetEvaluationsResponse(
                    evaluations: .mock1,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )

        let dao = MockEvaluationDao()
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
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
                XCTAssertEqual(interactor.evaluations[User.mock1.id], [.mock1, .mock2])

                let evaluation = interactor.getLatest(
                    userId: User.mock1.id,
                    featureId: "feature1"
                )
                XCTAssertEqual(evaluation, .mock1)

                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1)
    }

    func testFetchAndFailWithDBError() {
        let expectation = XCTestExpectation()

        let baseUserEvaluationsId = UserEvaluations.mock1.id
        let api = MockApiClient(
            getEvaluationsHandler: { user, _, _, completion in

                XCTAssertEqual(user, .mock1)
                let response = GetEvaluationsResponse(
                    evaluations: .mock1,
                    userEvaluationsId: baseUserEvaluationsId
                )
                completion?(.success(response))
                expectation.fulfill()
            }
        )

        let dao = MockEvaluationDao(deleteAllAndInsertHandler: { _, _ in
            throw NSError(domain: "db", code: 100, userInfo: [:])
        })
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
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

    func testRefreshCache() throws {
        let api = MockApiClient()

        let userId1 = User.mock1.id
        let userId2 = User.mock2.id

        let dao = MockEvaluationDao(getHandler: { userId in
            switch userId {
            case userId1:
                return [.mock1, .mock2]
            case userId2:
                return [.mock3]
            default:
                return []
            }
        })
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        XCTAssertEqual(interactor.evaluations[userId1], nil)
        XCTAssertEqual(interactor.evaluations[userId2], nil)

        try interactor.refreshCache(userId: userId1)
        XCTAssertEqual(interactor.evaluations[userId1], [.mock1, .mock2])

        try interactor.refreshCache(userId: userId2)
        XCTAssertEqual(interactor.evaluations[userId2], [.mock3])
    }

    func testGetLatestWithCache() throws {
        let api = MockApiClient()

        let userId1 = User.mock1.id
        let userId2 = User.mock2.id

        let dao = MockEvaluationDao(getHandler: { userId in
            switch userId {
            case userId1:
                return [.mock1, .mock2]
            case userId2:
                return [.mock3]
            default:
                return []
            }
        })
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        try interactor.refreshCache(userId: userId1)

        XCTAssertEqual(interactor.getLatest(userId: userId1, featureId: Evaluation.mock1.featureId), .mock1)
    }

    func testGetLatestWithoutCache() {
        let api = MockApiClient()

        let dao = MockEvaluationDao(getHandler: { _ in
            return []
        })
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        XCTAssertEqual(interactor.getLatest(userId: User.mock1.id, featureId: Evaluation.mock1.featureId), nil)
    }

    func testGetLatestWithoutCorrespondingEvaluation() {
        let api = MockApiClient()

        let dao = MockEvaluationDao(getHandler: { userId in
            switch userId {
            case User.mock1.id:
                return [.mock1, .mock2]
            default:
                return []
            }
        })
        let defaults = MockDefaults()
        let idGenerator = MockIdGenerator(identifier: "")
        let config = BKTConfig.mock1

        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationDao: dao,
            defaults: defaults,
            idGenerator: idGenerator,
            featureTag: config.featureTag
        )

        XCTAssertEqual(interactor.getLatest(userId: User.mock1.id, featureId: "invalid_feature_id"), nil)
    }
}
// swiftlint:enable type_body_length
