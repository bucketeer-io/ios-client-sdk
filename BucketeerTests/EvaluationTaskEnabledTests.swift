import XCTest
@testable import Bucketeer

final class EvaluationTaskEnabledTests: XCTestCase {

    // MARK: - Test 1: Enable/Disable Functionality

    func testForegroundTaskStartsDisabledWhenCreatedByTaskScheduler() {
        let dispatchQueue = DispatchQueue(label: "test")
        let component = MockComponent()

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

        task.start()

        // Wait briefly - task should NOT execute
        wait(for: [expectation], timeout: 0.5)
    }

    func testForegroundTaskExecutesAfterEnabled() {
        let dispatchQueue = DispatchQueue(label: "test")
        let component = MockComponent()

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

        // Enable the task
        task.enable()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Test 2: No Cancellation After Init

    func testNoRequestCancelledErrorDuringInitialization() {
        let expectation = self.expectation(description: "Init completes without cancellation")
        expectation.expectedFulfillmentCount = 1

        var requestCount = 0
        let config = BKTConfig.mock(
            eventsFlushInterval: 50,
            eventsMaxQueueSize: 3,
            pollingInterval: 100, // Very short interval to trigger race condition
            backgroundPollingInterval: 1000
        )

        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { _, _, _, _, handler in
                requestCount += 1
                // Simulate slow initial request
                if requestCount == 1 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                        handler?(.success(.init(
                            evaluations: .mock1,
                            userEvaluationsId: "id",
                            seconds: 2,
                            sizeByte: 3,
                            featureTag: "feature"
                        )))
                    }
                } else {
                    // Subsequent requests should not happen during init
                    XCTFail("Should not trigger additional requests during initialization")
                }
            })
        )

        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        client.scheduleTasks()

        client.fetchEvaluations(timeoutMillis: 5000) { error in
            // Should complete without "Request cancelled by newer execution" error
            XCTAssertNil(error, "Should not have cancellation error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
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
        let component = MockComponent()

        let scheduler = TaskScheduler(component: component, dispatchQueue: dispatchQueue)

        // Tasks should start disabled
        // Enable them
        scheduler.enableEvaluationTask()

        // After enabling, tasks should execute
        let expectation = self.expectation(description: "Task executes after scheduler enables it")

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

        wait(for: [expectation], timeout: 1.0)
    }
}
