import XCTest
@testable import Bucketeer

final class EvaluationTaskEnabledTests: XCTestCase {

    // MARK: - Helpers

    private func assertEvaluationTasksEnabled(_ client: BKTClient, message: String = "after init") {
        let foregroundTask = client.taskScheduler?.foregroundSchedulers
            .compactMap({ $0 as? EvaluationForegroundTask }).first
        XCTAssertTrue(foregroundTask?.isTaskEnabled == true, "Evaluation foreground task should be enabled \(message)")

        let backgroundTask = client.taskScheduler?.backgroundSchedulers
            .compactMap({ $0 as? EvaluationBackgroundTask }).first
        XCTAssertTrue(backgroundTask?.isTaskEnabled == true, "Evaluation background task should be enabled \(message)")
    }

    // MARK: - Test 1: Enable/Disable Functionality

    func testForegroundTaskStartsDisabledByDefault() {
        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        // Use a config with short intervals to trigger execution quickly
        let config = BKTConfig.mock(pollingInterval: 100)
        let component = MockComponent(config: config)

        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue
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

    func testBackgroundTaskStartsDisabledByDefault() {
        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let config = BKTConfig.mock(pollingInterval: 100)
        let component = MockComponent(config: config)

        let task = EvaluationBackgroundTask(
            component: component,
            queue: dispatchQueue
        )

        XCTAssertFalse(task.isTaskEnabled, "Background task should be disabled initially")
        task.enable()
        XCTAssertTrue(task.isTaskEnabled, "Background task should be enabled after calling enable()")

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

        let task = EvaluationForegroundTask(
            component: component,
            queue: dispatchQueue,
            retryPollingInterval: 100,
            maxRetryCount: 1
        )

        task.start()
        XCTAssertFalse(task.isTaskEnabled, "Task should be disabled initially")
        // enable() is thread-safe (NSLock-protected), so no queue dispatch needed.
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
        completeExpectation.expectedFulfillmentCount = 2 // performInitialFetch completion + client.execute completion
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
            completeExpectation.fulfill()

            client.execute {
                // Poller must be enabled after performInitialFetch completes
                self.assertEvaluationTasksEnabled(client, message: "after init")
                completeExpectation.fulfill()
            }
        }

        wait(for: [completeExpectation], timeout: 15.0)

        client.destroy()
    }

    // MARK: - Test 3: Tasks Stay Enabled After Init

    func testTasksRemainEnabledAfterSuccessfulInit() {
        let networkReqExpectation = self.expectation(description: "Total network request should be 2")
        networkReqExpectation.expectedFulfillmentCount = 2 // Initial fetch + one poller execution
        networkReqExpectation.assertForOverFulfill = true

        let postInitExpectation = self.expectation(description: "Should check poller enable after init")
        postInitExpectation.expectedFulfillmentCount = 2 // Callback from performInitialFetch + finish checking enabled state
        postInitExpectation.assertForOverFulfill = true

        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 200,
            backgroundPollingInterval: 10000
        )

        let dataModule = MockDataModule(
            config: config,
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { _, _, _, _, handler in
                handler?(.success(.init(
                    evaluations: .mock1,
                    userEvaluationsId: "id",
                    seconds: 2,
                    sizeByte: 3,
                    featureTag: "feature"
                )))
                networkReqExpectation.fulfill()
            })
        )

        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let client = BKTClient(dataModule: dataModule, dispatchQueue: dispatchQueue)

        // performInitialFetch enables the poller internally after completion —
        // no manual taskScheduler?.enableEvaluationTask() needed
        client.performInitialFetch(timeoutMillis: 5000) { error in
            XCTAssertNil(error)
            postInitExpectation.fulfill()

            client.execute {
                self.assertEvaluationTasksEnabled(client, message: "after successful init")
                postInitExpectation.fulfill()
            }
        }

        wait(for: [networkReqExpectation, postInitExpectation], timeout: 15)
        client.destroy()
    }

    // MARK: - Test 4: Tasks Enabled Even After Init Failure

    func testTasksEnabledAfterFailedInit() {
        let networkReqExpectation = self.expectation(description: "Total network request should be 2")
        networkReqExpectation.expectedFulfillmentCount = 2 // Failed init + one successful poller execution
        networkReqExpectation.assertForOverFulfill = false

        let postInitExpectation = self.expectation(description: "Should check poller enable after init")
        postInitExpectation.expectedFulfillmentCount = 2 // Callback from performInitialFetch + finish checking enabled state
        postInitExpectation.assertForOverFulfill = true

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
                networkReqExpectation.fulfill()
            })
        )

        let dispatchQueue = DispatchQueue(label: "test.init.queue")
        let client = BKTClient(dataModule: dataModule, dispatchQueue: dispatchQueue)

        // performInitialFetch enables the poller internally even on failure —
        // no manual taskScheduler?.enableEvaluationTask() needed
        client.performInitialFetch(timeoutMillis: 5000) { e in
            XCTAssertNotNil(e, "First request should fail")
            postInitExpectation.fulfill()

            client.execute {
                self.assertEvaluationTasksEnabled(client, message: "even after failed init")
                postInitExpectation.fulfill()
            }
        }

        wait(for: [networkReqExpectation, postInitExpectation], timeout: 15)
        XCTAssertGreaterThanOrEqual(fetchCount, 2, "Task should be enabled even after init failure")

        client.destroy()
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

        // After enableEvaluationTask(), both tasks should be enabled.
        // enableEvaluationTask() is thread-safe (NSLock-protected inside each task),
        // so no queue dispatch is required.
        scheduler.enableEvaluationTask()
        XCTAssertTrue(evaluationForegroundTask!.isTaskEnabled, "Foreground task should be enabled after scheduler enables it")
        XCTAssertTrue(evaluationBackgroundTask!.isTaskEnabled, "Background task should be enabled after scheduler enables it")
        scheduler.stop()
    }
}
