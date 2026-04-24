import XCTest
@testable import Bucketeer

final class EvaluationTaskEnabledTests: XCTestCase {

    // MARK: - Test 1: Enable/Disable Functionality

    func testForegroundTaskStartsDisabledWhenCreatedByTaskScheduler() {
        let dispatchQueue = DispatchQueue(label: "test")
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
        let dispatchQueue = DispatchQueue(label: "test")
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

    func testNoRequestCancelledErrorDuringInitialization() {
        let completeExpectation = self.expectation(description: "Init completes without cancellation")
        completeExpectation.expectedFulfillmentCount = 1
        completeExpectation.assertForOverFulfill = true

        let requestCountExpectation = self.expectation(description: "This test is only exepect one request should be made during init")
        requestCountExpectation.assertForOverFulfill = true

        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 200, // Short interval to verify task stays enabled
            backgroundPollingInterval: 1000
        )
        let dataModule = MockDataModule(
            config: config,
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { _, _, _, _, handler in
                requestCountExpectation.fulfill()
                // Simulate slow initial request
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    handler?(.success(.init(
                        evaluations: .mock1,
                        userEvaluationsId: "id",
                        seconds: 2,
                        sizeByte: 3,
                        featureTag: "feature"
                    )))
                }
            })
        )

        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.scheduleTasks()

        client.fetchEvaluations(timeoutMillis: 5000) { error in
            // Should complete without "Request cancelled by newer execution" error
            XCTAssertNil(error, "Should not have cancellation error")
            completeExpectation.fulfill()
        }

        wait(for: [completeExpectation, requestCountExpectation], timeout: 5.0)
    }

    // MARK: - Test 3: Tasks Stay Enabled After Init

    func testTasksRemainEnabledAfterSuccessfulInit() {
        let expectation = self.expectation(description: "Tasks remain enabled")
        expectation.expectedFulfillmentCount = 2 // Initial fetch + one poller execution

        var fetchCount = 0
        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 200, // Short interval to verify task stays enabled
            backgroundPollingInterval: 1000
        )

        let dataModule = MockDataModule(
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

        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.scheduleTasks()

        client.fetchEvaluations(timeoutMillis: 5000) { error in
            XCTAssertNil(error)
            // After init completes, task should be enabled and continue polling
            client.taskScheduler?.enableEvaluationTask()
        }

        wait(for: [expectation], timeout: 1.5)
        XCTAssertGreaterThanOrEqual(fetchCount, 2, "Task should remain enabled and execute multiple times")
    }

    // MARK: - Test 4: Tasks Enabled Even After Init Failure

    func testTasksEnabledAfterFailedInit() {
        let expectation = self.expectation(description: "Tasks enabled after failed init")
        expectation.expectedFulfillmentCount = 2 // Failed init + one successful poller execution

        var fetchCount = 0
        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 200,
            backgroundPollingInterval: 1000
        )

        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { _, _, _, _, handler in
                fetchCount += 1
                if fetchCount == 1 {
                    // First request fails
                    handler?(.failure(
                        error: .timeout(message: "timeout", error: NSError(), timeoutMillis: 5000),
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

        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.scheduleTasks()

        client.fetchEvaluations(timeoutMillis: 5000) { error in
            XCTAssertNotNil(error, "First request should fail")
            // Even after failure, task should be enabled
            client.taskScheduler?.enableEvaluationTask()
        }

        wait(for: [expectation], timeout: 1.5)
        XCTAssertGreaterThanOrEqual(fetchCount, 2, "Task should be enabled even after init failure")
    }

    // MARK: - Test 5: TaskScheduler Integration

    func testTaskSchedulerEnablesEvaluationTask() {
        let dispatchQueue = DispatchQueue(label: "test")
        // Use a config with short intervals to trigger execution quickly
        let config = BKTConfig.mock(pollingInterval: 100)
        let component = MockComponent(config: config)

        let expectation = self.expectation(description: "Task executes after scheduler enables it")
        expectation.assertForOverFulfill = true
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

        let scheduler = TaskScheduler(component: component, dispatchQueue: dispatchQueue)
        // All tasks should be disable
        let evaluationForegroundTask = scheduler.foregroundSchedulers.compactMap { $0 as? EvaluationForegroundTask } .first
        XCTAssertNotNil(evaluationForegroundTask)
        XCTAssertFalse(evaluationForegroundTask!.isTaskEnabled, "Evaluation task should be disabled initially")

        let evaluationBackgroundTask = scheduler.backgroundSchedulers.compactMap { $0 as? EvaluationBackgroundTask } .first
        XCTAssertNotNil(evaluationBackgroundTask)
        XCTAssertFalse(evaluationBackgroundTask!.isTaskEnabled, "Evaluation task should be disabled initially")

        // Enable them
        scheduler.enableEvaluationTask()

        // Both foreground and background tasks should be enabled
        XCTAssertTrue(evaluationForegroundTask!.isTaskEnabled, "Evaluation task should be enabled after scheduler enables it")
        XCTAssertTrue(evaluationBackgroundTask!.isTaskEnabled, "Evaluation task should be enabled after scheduler enables it")

        wait(for: [expectation], timeout: 1.0)
    }
}
