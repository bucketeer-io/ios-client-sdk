import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length
final class BKTClientTests: XCTestCase {

    func testCurrentUser() {
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        XCTAssertEqual(client.currentUser()?.id, User.mock1.toBKTUser().id)
        XCTAssertEqual(client.currentUser()?.attr, User.mock1.toBKTUser().attr)
    }

    func testUpdateUserAttributes() {
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        let attributes: [String: String] = ["key": "updated"]
        client.updateUserAttributes(attributes: attributes)
        XCTAssertEqual(client.currentUser()?.attr, attributes)
    }

    func testUpdateUserAttributesAndResetEvaluationId() {
        let expectation = self.expectation(description: "")
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (_, _, _, handler) in
                handler?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "id",
                    seconds: 2,
                    sizeByte: 3,
                    featureTag: "feature"
                )))
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { error in
            XCTAssertEqual(error, nil)
            XCTAssertEqual(client.component.evaluationInteractor.currentEvaluationsId, "id")
            let attributes: [String: String] = ["key": "updated"]
            client.updateUserAttributes(attributes: attributes)
            XCTAssertEqual(client.component.evaluationInteractor.currentEvaluationsId, "")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testFetchEvaluationsSuccess() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        var count = 0
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, userEvaluationsId, timeoutMillis, handler) in
                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, "")
                XCTAssertEqual(timeoutMillis, nil)
                handler?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "id",
                    seconds: 2,
                    sizeByte: 3,
                    featureTag: "feature"
                )))
                expectation.fulfill()
            }),
            eventDao: MockEventDao(addEventsHandler: { events in
                XCTAssertEqual(events, [
                    Event(
                        id: "mock1",
                        event: .metrics(.init(
                            timestamp: 1,
                            event: .responseLatency(.init(
                                apiId: .getEvaluations,
                                labels: ["tag": "feature"],
                                latencySecond: .init(2)
                            )),
                            type: .responseLatency,
                            sourceId: .ios,
                            sdk_version: "0.0.2",
                            metadata: [
                                "app_version": "1.2.3",
                                "os_version": "16.0",
                                "device_model": "iPhone14,7",
                                "device_type": "mobile"
                            ]
                        )),
                        type: .metrics
                    ),
                    Event(
                        id: "mock2",
                        event: .metrics(.init(
                            timestamp: 1,
                            event: .responseSize(.init(
                                apiId: .getEvaluations,
                                labels: ["tag": "feature"],
                                sizeByte: 3
                            )),
                            type: .responseSize,
                            sourceId: .ios,
                            sdk_version: "0.0.2",
                            metadata: [
                                "app_version": "1.2.3",
                                "os_version": "16.0",
                                "device_model": "iPhone14,7",
                                "device_type": "mobile"
                            ]
                        )),
                        type: .metrics
                    )
                ])
                expectation.fulfill()
            }),
            idGenerator: MockIdGenerator(identifier: {
                count += 1
                return "mock\(count)"
            }),
            clock: MockClock(timestamp: 1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { error in
            XCTAssertEqual(error, nil)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testFetchEvaluationsFailure() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        var count = 0
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, userEvaluationsId, timeoutMillis, handler) in
                XCTAssertEqual(user, .mock1)
                XCTAssertEqual(userEvaluationsId, "")
                XCTAssertEqual(timeoutMillis, nil)
                handler?(.failure(error: .timeout(message: "timeout", error: NSError()), featureTag: "feature"))
                expectation.fulfill()
            }),
            eventDao: MockEventDao(addEventsHandler: { events in
                XCTAssertEqual(events.count, 1)
                let expected = Event(
                    id: "mock1",
                    event: .metrics(.init(
                        timestamp: 1,
                        event: .timeoutError(.init(apiId: .getEvaluations, labels: ["tag": "feature"])),
                        type: .timeoutError,
                        sourceId: .ios,
                        sdk_version: "0.0.2",
                        metadata: [
                            "app_version": "1.2.3",
                            "os_version": "16.0",
                            "device_model": "iPhone14,7",
                            "device_type": "mobile"
                        ]
                    )),
                    type: .metrics
                )
                XCTAssertEqual(expected, events.first)
                expectation.fulfill()
            }),
            idGenerator: MockIdGenerator(identifier: {
                count += 1
                return "mock\(count)"
            }),
            clock: MockClock(timestamp: 1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { error in
            XCTAssertEqual(error, .timeout(message: "timeout", error: NSError()))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testFlushSuccess() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(registerEventsHandler: { events, handler in
                XCTAssertEqual(events, [.mockGoal1, .mockEvaluation1])
                handler?(.success(.init(errors: [:])))
                expectation.fulfill()
            }),
            eventDao: MockEventDao(getEventsHandler: {
                defer { expectation.fulfill() }
                return [.mockGoal1, .mockEvaluation1]
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.flush { error in
            XCTAssertEqual(error, nil)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testFlushFailure() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 4
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(registerEventsHandler: { events, handler in
                XCTAssertEqual(events, [.mockGoal1, .mockEvaluation1])
                handler?(.failure(.apiServer(message: "unknown")))
                expectation.fulfill()
            }),
            eventDao: MockEventDao(getEventsHandler: {
                defer {
                    // It will call 2 times.
                    // 1 for prepare for flushing
                    // 2 for checking duplicate
                    expectation.fulfill()
                }
                return [.mockGoal1, .mockEvaluation1]
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.flush { error in
            XCTAssertEqual(error, .apiServer(message: "unknown"))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testEvaluationDetailsEmpty() {
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        let evaluation = client.evaluationDetails(featureId: "feature")
        XCTAssertEqual(evaluation, nil)
    }

    func testEvaluationDetails() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, handler) in
                XCTAssertEqual(user, .mock1)
                handler?(.success(.init(evaluations: .mock1, userEvaluationsId: "new")))
                expectation.fulfill()
            }),
            evaluationDao: MockEvaluationDao(deleteAllAndInsertHandler: { id, evaluations in
                XCTAssertEqual(id, User.mock1.id)
                XCTAssertEqual(evaluations, [.mock1, .mock2])
                expectation.fulfill()
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            let evaluation = client.evaluationDetails(featureId: "feature1")
            let expected = BKTEvaluation(
                id: "evaluation1",
                featureId: "feature1",
                featureVersion: 1,
                userId: User.mock1.id,
                variationId: "variation1",
                variationValue: "variation_value1",
                reason: .rule
            )
            XCTAssertEqual(evaluation, expected)
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testTrackGoal() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 1
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            eventDao: MockEventDao(addEventsHandler: { events in

                XCTAssertEqual(events.count, 1)

                XCTAssertEqual(events.first, Event(
                    id: "id",
                    event: .goal(.init(
                        timestamp: 1,
                        goalId: "goalId",
                        userId: User.mock1.id,
                        value: 20,
                        user: .mock1,
                        tag: "featureTag1",
                        sourceId: .ios,
                        sdkVersion: "0.0.2",
                        metadata: [
                            "app_version": "1.2.3",
                            "os_version": "16.0",
                            "device_model": "iPhone14,7",
                            "device_type": "mobile"
                        ]
                    )),
                    type: .goal
                ))
                expectation.fulfill()
            }),
            idGenerator: MockIdGenerator(identifier: "id"),
            clock: MockClock(timestamp: 1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.track(goalId: "goalId", value: 20)
        wait(for: [expectation], timeout: 0.1)
    }

    func testStringVariationAsDefault() {
        let dataModule = MockDataModule()
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        let string = client.stringVariation(featureId: "feature1", defaultValue: "")
        XCTAssertEqual(string, "")
    }

    func testStringVariation() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, handler) in
                XCTAssertEqual(user, .mock1)
                handler?(.success(.init(evaluations: .mock1, userEvaluationsId: "new")))
                expectation.fulfill()
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            let string = client.stringVariation(featureId: "feature1", defaultValue: "")
            XCTAssertEqual(string, "variation_value1")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testIntVariation() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, handler) in
                XCTAssertEqual(user, .mock1)
                handler?(.success(.init(evaluations: .mock1, userEvaluationsId: "new")))
                expectation.fulfill()
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            let value = client.intVariation(featureId: "feature2", defaultValue: 0)
            XCTAssertEqual(value, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testDoubleVariation() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, handler) in
                XCTAssertEqual(user, .mock1)
                handler?(.success(.init(evaluations: .mock2, userEvaluationsId: "new")))
                expectation.fulfill()
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            let value = client.doubleVariation(featureId: "feature3", defaultValue: 0)
            XCTAssertEqual(value, 3.0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testBoolVariation() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock2),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, handler) in
                XCTAssertEqual(user, .mock2)
                handler?(.success(.init(evaluations: .mock2, userEvaluationsId: "new")))
                expectation.fulfill()
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            let value = client.boolVariation(featureId: "feature4", defaultValue: false)
            XCTAssertEqual(value, true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testJSONVariation() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock2),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, handler) in
                XCTAssertEqual(user, .mock2)
                handler?(.success(.init(evaluations: .mock2, userEvaluationsId: "new")))
                expectation.fulfill()
            })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            let value = client.jsonVariation(featureId: "feature5", defaultValue: [:])
            XCTAssertEqual(value, ["key": "value"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }
}
// swiftlint:enable type_body_length
