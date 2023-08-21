import XCTest
@testable import Bucketeer

final class EvaluationForegroundTaskTests: XCTestCase {
    func testStartAndReceiveSuccess() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true
        let dispatchQueue = DispatchQueue(label: "default", qos: .default)

        let featureTag = "featureTag1"
        let evaluationInteractor = MockEvaluationInteractor(
            fetchHandler: { user, timeoutMillis, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertNil(timeoutMillis)
                completion?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "user_evaluation",
                    seconds: 1,
                    sizeByte: 2,
                    featureTag: featureTag
                )))
            }
        )
        let eventInteractor = MockEventInteractor(
            trackEvaluationSuccessHandler: { tag, seconds, sizeBytes in
                XCTAssertEqual(tag, featureTag)
                XCTAssertEqual(seconds, 1)
                XCTAssertEqual(sizeBytes, 2)
                expectation.fulfill()
            }
        )
        let config = BKTConfig.mock(
            eventsFlushInterval: 10,
            eventsMaxQueueSize: 3,
            pollingInterval: 5000, // The minimum polling interval is 60 seconds, but is set to 5 seconds to shorten the test.
            backgroundPollingInterval: 1000
        )
        let component = MockComponent(
            config: config,
            evaluationInteractor: evaluationInteractor,
            eventInteractor: eventInteractor
        )
        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue
        )
        task.start()

        wait(for: [expectation], timeout: 20)
    }

    func testStartAndReceiveError() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 6
        expectation.assertForOverFulfill = true
        let dispatchQueue = DispatchQueue(label: "default", qos: .default)

        let error: BKTError = .badRequest(message: "bad request")
        let featureTag = "featureTag1"
        let evaluationInteractor = MockEvaluationInteractor(
            fetchHandler: { user, timeoutMillis, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertNil(timeoutMillis)
                completion?(.failure(error: error, featureTag: featureTag))
            }
        )
        var count: Int = 0
        let eventInteractor = MockEventInteractor(
            trackEvaluationFailureHandler: { tag, e in
                XCTAssertEqual(tag, featureTag)
                XCTAssertEqual(e, error)
                XCTAssert(count < 6) // first and 5 retry
                expectation.fulfill()
                count += 1
            }
        )

        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 5000, // The minimum polling interval is 60 seconds, but is set to 5 seconds to shorten the test.
            backgroundPollingInterval: 1000
        )

        XCTAssertNotNil(config, "BKTConfig should not be null")

        let component = MockComponent(
            config: config,
            evaluationInteractor: evaluationInteractor,
            eventInteractor: eventInteractor
        )
        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue,
            retryPollingInterval: 1,
            maxRetryCount: 5
        )
        task.start()

        wait(for: [expectation], timeout: 20)
    }

    func testStop() {
        let expectation = self.expectation(description: "")
        expectation.isInverted = true
        let dispatchQueue = DispatchQueue(label: "default", qos: .default)

        let error: BKTError = .badRequest(message: "bad request")
        let evaluationInteractor = MockEvaluationInteractor(
            fetchHandler: { user, timeoutMillis, completion in
                XCTAssertEqual(user, .mock1)
                XCTAssertNil(timeoutMillis)
                completion?(.failure(error: error, featureTag: "featureTag1"))
            }
        )
        let eventInteractor = MockEventInteractor(
            trackEvaluationFailureHandler: { _, _ in
                expectation.fulfill()
            }
        )
        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 100,
            backgroundPollingInterval: 1000
        )
        let component = MockComponent(
            config: config,
            evaluationInteractor: evaluationInteractor,
            eventInteractor: eventInteractor
        )
        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue,
            retryPollingInterval: 1,
            maxRetryCount: 5
        )
        task.start()
        task.stop()

        wait(for: [expectation], timeout: 0.1)
    }
}
