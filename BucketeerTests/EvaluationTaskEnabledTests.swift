import XCTest
@testable import Bucketeer

final class EvaluationTaskEnabledTests: XCTestCase {

    // MARK: - Test 1: Enable/Disable Functionality

    func testForegroundTaskStartsDisabledWhenCreatedByTaskScheduler() {
        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        // Use a config with short intervals to trigger execution quickly
        let config = BKTConfig.mock(pollingInterval: 100)
        let component = MockComponent(config: config)

        // Create task with enabled: false (as TaskScheduler does)
        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue,
            enabled: false
        )

        let expectation = self.expectation(description: "Should not execute when disabled")
        expectation.isInverted = true

        let evaluationInteractor = MockEvaluationInteractor(
            fetchHandler: { _, _, _ in
                expectation.fulfill()
            }
        )
        component.evaluationInteractor = evaluationInteractor
        XCTAssertFalse(task.isTaskEnabled, "Task should be disabled initially")
        task.start()

        // Wait briefly - task should NOT execute
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(task.isTaskEnabled, "Task should be disabled initially")
        task.stop()
    }

    func testForegroundTaskExecutesAfterEnabled() {
        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        // Use a config with short intervals to trigger execution quickly
        let config = BKTConfig.mock(pollingInterval: 100)
        let component = MockComponent(config: config)

        let expectation = self.expectation(description: "Should execute after enabled")
        expectation.expectedFulfillmentCount = 1

        let evaluationInteractor = MockEvaluationInteractor(
            fetchHandler: { _, _, completion in
                completion?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "test",
                    seconds: 1,
                    sizeByte: 100,
                    featureTag: "test"
                )))
                expectation.fulfill()
            }
        )
        component.evaluationInteractor = evaluationInteractor

        // Create disabled task
        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue,
            retryPollingInterval: 100,
            maxRetryCount: 1,
            enabled: false
        )

        task.start()
        XCTAssertFalse(task.isTaskEnabled, "Task should be disabled initially")
        // Enable the task
        task.enable()
        XCTAssertTrue(task.isTaskEnabled, "Task should be enabled")

        wait(for: [expectation], timeout: 1.0)

        task.stop()
    }

    // MARK: - Test 2: No Cancellation After Init

    // Simulates the real-world scenario: server returns HTTP 499 (clientClosed) continuously,
    // causing ApiClientImpl to retry with exponential backoff.
    // Without the fix, the foreground poller fires during retries, creates a new requestId,
    // and cancels the retrying request with BKTError.illegalState("Request cancelled by newer execution").
    // With performInitialFetch, the poller is disabled until init completes, so all 4 attempts run cleanly.
    func testNoRequestCancelledErrorDuringInitialization() {
        let completeExpectation = self.expectation(description: "Init completes without cancellation error")
        completeExpectation.assertForOverFulfill = true

        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!

        // Always return 499 to trigger retry logic inside ApiClientImpl
        let session = MockSession(
            configuration: .default,
            data: Data("{}".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(ApiPaths.getEvaluations.rawValue),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let apiClient = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "api-key",
            featureTag: "feature",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: dispatchQueue),
            logger: nil
        )

        // pollingInterval is shorter than the total retry window (1s+2s+4s backoff),
        // so without the fix the poller would fire and cancel the retrying request.
        let config = BKTConfig.mock(
            pollingInterval: 300,
            backgroundPollingInterval: 10000
        )
        let dataModule = MockDataModule(
            config: config,
            userHolder: .init(user: .mock1),
            apiClient: apiClient
        )

        let client = BKTClient(dataModule: dataModule, dispatchQueue: dispatchQueue)

        client.performInitialFetch(timeoutMillis: 5000) { error in
            // Must be .clientClosed (499 exhausted all retries cleanly), NOT .illegalState (cancelled)
            XCTAssertNotNil(error, "Should receive an error after retries exhausted")
            if case .illegalState = error {
                XCTFail("Request was cancelled by the poller — fix is not working")
            }
            if case .clientClosed = error {
                // Expected: all 4 attempts ran to completion
            } else {
                XCTFail("Unexpected error type: \(String(describing: error))")
            }
            // All 4 attempts (1 original + 3 retries) must have completed without cancellation
            XCTAssertEqual(session.requestCount(), 4, "Should attempt exactly 4 times (1 + 3 retries)")
            // Poller must be enabled after performInitialFetch completes
            let foregroundTask = client.taskScheduler?.foregroundSchedulers
                .compactMap({ $0 as? EvaluationForegroundTask }).first
            XCTAssertTrue(foregroundTask?.isTaskEnabled == true, "Evaluation task should be enabled after init")
            completeExpectation.fulfill()
        }

        wait(for: [completeExpectation], timeout: 15.0)
    }

    // MARK: - Test 3: Tasks Stay Enabled After Init

    func testTasksRemainEnabledAfterSuccessfulInit() {
        let expectation = self.expectation(description: "Tasks remain enabled")
        expectation.expectedFulfillmentCount = 2 // Initial fetch + one poller execution
        expectation.assertForOverFulfill = false

        var fetchCount = 0
        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 200,
            backgroundPollingInterval: 1000
        )

        let dataModule = MockDataModule(
            config: config,
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { _, _, _, _, handler in
                fetchCount += 1
                handler?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "id",
                    seconds: 2,
                    sizeByte: 3,
                    featureTag: "feature"
                )))
                expectation.fulfill()
            })
        )

        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let client = BKTClient(dataModule: dataModule, dispatchQueue: dispatchQueue)

        // performInitialFetch enables the poller internally after completion —
        // no manual taskScheduler?.enableEvaluationTask() needed
        client.performInitialFetch(timeoutMillis: 5000) { error in
            XCTAssertNil(error)
            let foregroundTask = client.taskScheduler?.foregroundSchedulers
                .compactMap({ $0 as? EvaluationForegroundTask }).first
            XCTAssertTrue(foregroundTask?.isTaskEnabled == true, "Evaluation task should be enabled after init")
        }

        wait(for: [expectation], timeout: 1.5)
        XCTAssertGreaterThanOrEqual(fetchCount, 2, "Task should remain enabled and execute multiple times")
    }

    // MARK: - Test 4: Tasks Enabled Even After Init Failure

    func testTasksEnabledAfterFailedInit() {
        let expectation = self.expectation(description: "Tasks enabled after failed init")
        expectation.expectedFulfillmentCount = 2 // Failed init + one successful poller execution
        expectation.assertForOverFulfill = false

        var fetchCount = 0
        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 200,
            backgroundPollingInterval: 1000
        )

        let dataModule = MockDataModule(
            config: config,
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { _, _, _, _, handler in
                fetchCount += 1
                if fetchCount == 1 {
                    // First request fails
                    handler?(.failure(
                        error: .timeout(message: "timeout", error: NSError(domain: "test", code: -1, userInfo: nil), timeoutMillis: 5000),
                        featureTag: "feature"
                    ))
                } else {
                    // Subsequent requests succeed
                    handler?(.success(.init(
                        evaluations: .mock1,
                        userEvaluationsId: "id",
                        seconds: 2,
                        sizeByte: 3,
                        featureTag: "feature"
                    )))
                }
                expectation.fulfill()
            })
        )

        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let client = BKTClient(dataModule: dataModule, dispatchQueue: dispatchQueue)

        // performInitialFetch enables the poller internally even on failure —
        // no manual taskScheduler?.enableEvaluationTask() needed
        client.performInitialFetch(timeoutMillis: 5000) { e in
            XCTAssertNotNil(e, "First request should fail")
            let foregroundTask = client.taskScheduler?.foregroundSchedulers
                .compactMap({ $0 as? EvaluationForegroundTask }).first
            XCTAssertTrue(foregroundTask?.isTaskEnabled == true, "Evaluation task should be enabled even after failed init")
        }

        wait(for: [expectation], timeout: 1.5)
        XCTAssertGreaterThanOrEqual(fetchCount, 2, "Task should be enabled even after init failure")
    }

    // MARK: - Test 5: TaskScheduler Integration

    func testTaskSchedulerEnablesEvaluationTask() {
        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let config = BKTConfig.mock(pollingInterval: 100)
        let component = MockComponent(config: config)

        let scheduler = TaskScheduler(component: component, dispatchQueue: dispatchQueue)

        // Both tasks should start disabled
        let evaluationForegroundTask = scheduler.foregroundSchedulers
            .compactMap({ $0 as? EvaluationForegroundTask }).first
        XCTAssertNotNil(evaluationForegroundTask)
        XCTAssertFalse(evaluationForegroundTask!.isTaskEnabled, "Foreground task should be disabled initially")

        let evaluationBackgroundTask = scheduler.backgroundSchedulers
            .compactMap({ $0 as? EvaluationBackgroundTask }).first
        XCTAssertNotNil(evaluationBackgroundTask)
        XCTAssertFalse(evaluationBackgroundTask!.isTaskEnabled, "Background task should be disabled initially")

        // After enableEvaluationTask(), both tasks should be enabled
        scheduler.enableEvaluationTask()
        XCTAssertTrue(evaluationForegroundTask!.isTaskEnabled, "Foreground task should be enabled after scheduler enables it")
        XCTAssertTrue(evaluationBackgroundTask!.isTaskEnabled, "Background task should be enabled after scheduler enables it")
    }
}
