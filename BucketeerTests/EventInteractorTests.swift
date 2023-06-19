import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length file_length
final class EventInteractorTests: XCTestCase {
    private func eventInteractor(api: ApiClient = MockApiClient(),
                                 dao: EventDao = MockEventDao(),
                                 config: BKTConfig = BKTConfig.mock(),
                                 idGenerator: IdGenerator = MockIdGenerator(identifier: "id")
    ) -> EventInteractor {
        let clock = MockClock(timestamp: 1)
        let logger = MockLogger()
        return EventInteractorImpl(
            sdkVersion: "0.0.2",
            appVersion: "1.2.3",
            device: MockDevice(),
            eventsMaxBatchQueueCount: 3,
            apiClient: api,
            eventDao: dao,
            clock: clock,
            idGenerator: idGenerator,
            logger: logger,
            featureTag: config.featureTag
        )
    }

    func testTrackEvaluationEvent() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 1)
            let expected = Event(
                id: "id",
                event: .evaluation(.init(
                    timestamp: 1,
                    featureId: Evaluation.mock1.featureId,
                    featureVersion: Evaluation.mock1.featureVersion,
                    userId: User.mock1.id,
                    variationId: Evaluation.mock1.variationId,
                    user: .mock1,
                    reason: Evaluation.mock1.reason,
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
                type: .evaluation
            )
            XCTAssertEqual(events, [expected])
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        try interactor.trackEvaluationEvent(
            featureTag: "featureTag1",
            user: .mock1,
            evaluation: .mock1
        )
        wait(for: [expectation], timeout: 1)
    }

    func testTrackDefaultEvaluationEvent() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true

        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 1)
            let expected = Event(
                id: "id",
                event: .evaluation(.init(
                    timestamp: 1,
                    featureId: "featureId1",
                    userId: User.mock1.id,
                    user: .mock1,
                    reason: .init(type: .client),
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
                type: .evaluation
            )
            XCTAssertEqual(events, [expected])
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        try interactor.trackDefaultEvaluationEvent(
            featureTag: "featureTag1",
            user: .mock1,
            featureId: "featureId1"
        )
        wait(for: [expectation], timeout: 1)
    }

    func testTrackGoalEvent() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true

        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 1)
            let expected = Event(
                id: "id",
                event: .goal(.init(
                    timestamp: 1,
                    goalId: "goalId1",
                    userId: User.mock1.id,
                    value: 1,
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
            )
            XCTAssertEqual(events, [expected])
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        try interactor.trackGoalEvent(
            featureTag: "featureTag1",
            user: .mock1,
            goalId: "goalId1",
            value: 1
        )
        wait(for: [expectation], timeout: 1)
    }

    func testTrackFetchEvaluationsSuccess() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true

        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 2)
            let expected: [Event] = [
                Event(
                    id: "id",
                    event: .metrics(.init(
                        timestamp: 1,
                        event: .responseLatency(.init(
                            apiId: .getEvaluations,
                            labels: ["tag": "featureTag1"],
                            latencySecond: .init(10)
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
                    id: "id",
                    event: .metrics(.init(
                        timestamp: 1,
                        event: .responseSize(.init(
                            apiId: .getEvaluations,
                            labels: ["tag": "featureTag1"],
                            sizeByte: 100
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
            ]
            XCTAssertEqual(events, expected)
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        try interactor.trackFetchEvaluationsSuccess(
            featureTag: "featureTag1",
            seconds: 10,
            sizeByte: 100
        )
        wait(for: [expectation], timeout: 1)
    }

    enum SomeError: Error {
        case a
    }

    func testTrackFetchEvaluationsFailureWithTimeout() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true

        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 1)
            let expected: [Event] = [
                Event(
                    id: "id",
                    event: .metrics(.init(
                        timestamp: 1,
                        event: .timeoutError(.init(apiId: .getEvaluations, labels: ["tag": "featureTag1"])),
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
            ]
            XCTAssertEqual(events, expected)
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        try interactor.trackFetchEvaluationsFailure(
            featureTag: "featureTag1",
            error: .timeout(message: "timeout", error: SomeError.a)
        )
        wait(for: [expectation], timeout: 1)
    }

    func testTrackFetchEvaluationsFailureWithOtherError() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true

        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 1)
            let expected: [Event] = [
                Event(
                    id: "id",
                    event: .metrics(.init(
                        timestamp: 1,
                        event: .badRequestError(.init(apiId: .getEvaluations, labels: ["tag": "featureTag1"])),
                        type: .badRequestError,
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
            ]
            XCTAssertEqual(events, expected)
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        try interactor.trackFetchEvaluationsFailure(
            featureTag: "featureTag1",
            error: .badRequest(message: "bad request")
        )
        wait(for: [expectation], timeout: 1)
    }

    func testSendEventsSuccess() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3

        let addedEvents: [Event] = [.mockEvaluation1, .mockGoal1]
        let dao = MockEventDao()
        try dao.add(events: addedEvents)
        let api = MockApiClient(registerEventsHandler: { events, completion in
            XCTAssertEqual(events.count, 2)
            XCTAssertEqual(events, addedEvents)
            completion?(.success(.init(errors: [:])))
            expectation.fulfill()
        })
        let interactor = self.eventInteractor(api: api, dao: dao)
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 0)
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        interactor.sendEvents(force: true, completion: { result in
            switch result {
            case .success(let success):
                XCTAssertTrue(success)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }

    func testSendEventsFailure() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3

        let addedEvents: [Event] = [.mockEvaluation1, .mockGoal1, .mockGoal2]
        let dao = MockEventDao()
        try dao.add(events: addedEvents)

        let error = BKTError.badRequest(message: "bad request")
        let api = MockApiClient(registerEventsHandler: { events, completion in
            XCTAssertEqual(events, addedEvents)
            completion?(.failure(error))
            expectation.fulfill()
        })
        let config = BKTConfig.mock()
        let interactor = self.eventInteractor(api: api, dao: dao, config: config)
        let listener = MockEventUpdateListener { events in
            // Check if error metrics tracked after `register_event` fail
            // In this case we expected `.badRequestError`
            let badRequestMetricsEvent = Event(
                id: "id",
                event: .metrics(.init(
                    timestamp: 1,
                    event: .badRequestError(.init(
                        apiId: .registerEvents,
                        // Error metrics labels["tag"] should the same with the current `BKTConfig.featureTag`
                        // https://github.com/bucketeer-io/android-client-sdk/pull/64#discussion_r1214443320
                        labels: ["tag":config.featureTag]
                    )),
                    type: .badRequestError,
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
            let expectedEvents: [Event] = [.mockEvaluation1, .mockGoal1, .mockGoal2, badRequestMetricsEvent]
            XCTAssertEqual(events, expectedEvents)
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        interactor.sendEvents(completion: { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let e):
                XCTAssertEqual(e, error)
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }

    func testPreventDuplicateMetricsEvent() throws {
        var count = 0
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = false
        expectation.expectedFulfillmentCount = 2

        var expectedEvents: [Event] = [
            .idMock1ReponseLatencyEvent,
            .idMock2ResponseSizeEvent,
            .idMock3InternalServerErrorEvent,
            .idMock4BadRequestErrorEvent
        ]

        let api = MockApiClient(registerEventsHandler: { _, completion in
            completion?(.success(.init(errors: [:])))
            expectation.fulfill()
        })

        let dao = MockEventDao()
        let idGenerator = MockIdGenerator(identifier: {
            count += 1
            return "mock\(count)"
        })

        let interactor = self.eventInteractor(api: api, dao: dao, idGenerator: idGenerator)

        // Simulate track metrics events
        // Simulate success send events & tracked 2 events (response_latency & reponse_size)
        try interactor.trackFetchEvaluationsSuccess(featureTag: "featureTag1", seconds: 1, sizeByte: 789)
        // Try continue send events but fail. Track 1 metrics error event (InternalServerError)
        try interactor.trackFetchEvaluationsFailure(featureTag: "featureTag1", error: .apiServer(message: "unknown"))
        // Try continue send events but fail. Track 1 metrics error event (Bad Request)
        try interactor.trackRegisterEventsFailure(error: .badRequest(message: "bad request"))

        var storedEvents = try dao.getEvents()
        XCTAssertEqual(storedEvents, expectedEvents)

        // Try continue send events but fail. Duplicate , will not track | id = 5
        try interactor.trackFetchEvaluationsFailure(featureTag: "featureTag1", error: .apiServer(message: "unknown"))
        // Try continue send events but fail. Duplicate , will not track | id = 6
        try interactor.trackRegisterEventsFailure(error: .badRequest(message: "bad request"))

        storedEvents = try dao.getEvents()
        XCTAssertEqual(storedEvents, expectedEvents)

        // Simulate send all events success
        interactor.sendEvents(completion: { result in
            switch result {
            case .success(let success):
                XCTAssertTrue(success)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        })

        // Cache events database should not empty, because Current test `eventsMaxBatchQueueCount` = 3
        // So that we will have one more metrics event in cache
        storedEvents = try dao.getEvents()
        XCTAssertEqual(storedEvents.count, 1)
        XCTAssertEqual(storedEvents, [
            .idMock4BadRequestErrorEvent
        ])

        // Simulate track metrics events
        // Try continue send events but fail. Should tracked | id = 7
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [:])
        try interactor.trackFetchEvaluationsFailure(featureTag: "featureTag1", error: .timeout(message: "unknown", error: timeoutError))
        // Try continue send events but fail. Should not track | id = 8
        try interactor.trackRegisterEventsFailure(error: .badRequest(message: "bad request"))
        storedEvents = try dao.getEvents()
        expectedEvents = [
            .idMock4BadRequestErrorEvent,
            .idMock7TimeoutErrorEvent
        ]
        XCTAssertEqual(storedEvents, expectedEvents)
    }

    func testSendEventsCurrentIsEmpty() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        let interactor = self.eventInteractor()
        let listener = MockEventUpdateListener()
        interactor.set(eventUpdateListener: listener)
        interactor.sendEvents(completion: { result in
            switch result {
            case .success(let success):
                XCTAssertFalse(success)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }

    func testSendEventsNotEnoughEvents() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        let addedEvents: [Event] = [.mockEvaluation1, .mockGoal1]
        let dao = MockEventDao()
        try dao.add(events: addedEvents)

        let interactor = self.eventInteractor(dao: dao)
        let listener = MockEventUpdateListener()
        interactor.set(eventUpdateListener: listener)
        interactor.sendEvents(completion: { result in
            switch result {
            case .success(let success):
                XCTAssertFalse(success)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)    }

    func testSendEventsForce() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3

        let addedEvents: [Event] = [.mockEvaluation1]
        let dao = MockEventDao()
        try dao.add(events: addedEvents)
        let api = MockApiClient(registerEventsHandler: { events, completion in
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(events, addedEvents)
            completion?(.success(.init(errors: [:])))
            expectation.fulfill()
        })

        let interactor = self.eventInteractor(api: api, dao: dao)
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 0)
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        interactor.sendEvents(force: true, completion: { result in
            switch result {
            case .success(let success):
                XCTAssertTrue(success)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }

    func testSendEventsRetriableError() throws {
        let expectation = XCTestExpectation()
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3

        let addedEvents: [Event] = [.mockEvaluation1, .mockGoal1]
        let dao = MockEventDao()
        try dao.add(events: addedEvents)

        XCTAssertEqual(dao.events.count, 2)
        XCTAssertEqual(dao.events, addedEvents)

        let api = MockApiClient(registerEventsHandler: { events, completion in
            XCTAssertEqual(events.count, 2)
            XCTAssertEqual(events, addedEvents)
            completion?(.success(.init(
                errors: [
                    Event.mockEvaluation1.id: .init(retriable: true, message: "message")
                ]
            )))
            expectation.fulfill()
        })

        let interactor = self.eventInteractor(api: api, dao: dao)
        let listener = MockEventUpdateListener { events in
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(events, [.mockEvaluation1])
            expectation.fulfill()
        }
        interactor.set(eventUpdateListener: listener)
        interactor.sendEvents(force: true, completion: { result in
            switch result {
            case .success(let success):
                XCTAssertTrue(success)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 1)
    }
}
// swiftlint:enable type_body_length file_length
