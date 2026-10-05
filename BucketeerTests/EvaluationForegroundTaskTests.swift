import XCTest
@testable import Bucketeer

final class EvaluationForegroundTaskTests: XCTestCase {
    func testStartAndReceiveSuccess() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
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
        task.enable()

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
            retryPollingInterval: 1000,
            maxRetryCount: 5
        )
        task.start()
        task.enable()

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

    // The streaming fallback needs fresh evaluations as soon as the stream drops, not one
    // full pollingInterval later.
    func testStartImmediatelyFetchesRightAwayThenKeepsPolling() {
        let firstFetch = expectation(description: "first fetch")
        let secondFetch = expectation(description: "second fetch")
        let recorder = FetchTimeRecorder(expectations: [firstFetch, secondFetch])
        let task = makeTask(pollingInterval: 1000, recorder: recorder)
        defer { task.stop() }

        task.enable()
        let startedAt = Date()
        task.start(immediately: true)

        wait(for: [firstFetch], timeout: 0.5)
        wait(for: [secondFetch], timeout: 3)
        let times = recorder.times.map { $0.timeIntervalSince(startedAt) }
        XCTAssertLessThan(times[0], 0.5, "the first fetch must not wait for the polling interval")
        XCTAssertGreaterThanOrEqual(times[1], 0.9, "the second fetch must come from the poller, one interval later")
    }

    func testStartWithoutImmediatelyWaitsForTheInterval() {
        let noEarlyFetch = expectation(description: "no fetch before the interval")
        noEarlyFetch.isInverted = true
        let recorder = FetchTimeRecorder(expectations: [noEarlyFetch])
        let task = makeTask(pollingInterval: 1000, recorder: recorder)
        defer { task.stop() }

        task.enable()
        task.start(immediately: false)

        wait(for: [noEarlyFetch], timeout: 0.5)
        let firstTick = expectation(description: "fetch on the first tick")
        recorder.expectNext([firstTick])
        wait(for: [firstTick], timeout: 3)
    }

    // iOS only: the streaming fallback starts after the initial fetch, so it is created
    // already enabled instead of waiting for TaskScheduler.enableEvaluationTask().
    func testCreatedEnabledFetchesWithoutEnable() {
        let firstTick = expectation(description: "fetch on the first tick")
        let recorder = FetchTimeRecorder(expectations: [firstTick])
        let task = makeTask(pollingInterval: 1000, recorder: recorder, enabled: true)
        defer { task.stop() }

        task.start()

        wait(for: [firstTick], timeout: 3)
    }

    private func makeTask(pollingInterval: Int64,
                          recorder: FetchTimeRecorder,
                          enabled: Bool = false) -> EvaluationForegroundTask {
        let evaluationInteractor = MockEvaluationInteractor(
            fetchHandler: { _, _, completion in
                recorder.record()
                completion?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "user_evaluation",
                    seconds: 1,
                    sizeByte: 2,
                    featureTag: "featureTag1"
                )))
            }
        )
        let component = MockComponent(
            config: BKTConfig.mock(pollingInterval: pollingInterval),
            evaluationInteractor: evaluationInteractor,
            eventInteractor: MockEventInteractor()
        )
        return EvaluationForegroundTask(
            component: component,
            queue: DispatchQueue(label: "io.bucketeer.test.EvaluationForegroundTask"),
            enabled: enabled
        )
    }
}

// Records when each fetch happens and fulfills one expectation per fetch, in order.
// Fetches run on the task's queue, the test reads on the main thread, so it is locked.
private final class FetchTimeRecorder {
    private let lock = NSLock()
    private var pending: [XCTestExpectation]
    private var _times: [Date] = []

    init(expectations: [XCTestExpectation]) {
        self.pending = expectations
    }

    var times: [Date] { lock.withLock { _times } }

    // Replaces what the next fetches fulfill, dropping anything not fulfilled yet.
    func expectNext(_ expectations: [XCTestExpectation]) {
        lock.withLock { pending = expectations }
    }

    func record() {
        let next: XCTestExpectation? = lock.withLock {
            _times.append(Date())
            return pending.isEmpty ? nil : pending.removeFirst()
        }
        next?.fulfill()
    }
}
