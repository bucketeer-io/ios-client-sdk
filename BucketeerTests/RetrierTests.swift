import XCTest
@testable import Bucketeer

final class RetrierTests: XCTestCase {

    var retrier: Retrier!
    var dispatchQueue: DispatchQueue!

    override func setUp() {
        super.setUp()
        // Use a serial queue for deterministic testing
        dispatchQueue = DispatchQueue(label: "io.bucketeer.tests.retrier")
        retrier = Retrier(queue: dispatchQueue)
    }

    override func tearDown() {
        retrier = nil
        dispatchQueue = nil
        super.tearDown()
    }

    func testAttemptSuccessOnFirstTry() {
        let expectation = self.expectation(description: "Task should succeed immediately")
        var attemptCount = 0

        dispatchQueue.async { [weak self] in
            self?.retrier.attempt(
                task: { completion in
                    attemptCount += 1
                    completion(.success("Success"))
                },
                condition: { _ in true },
                maxAttempts: 3,
                completion: { result in
                    switch result {
                    case .success(let value):
                        XCTAssertEqual(value, "Success")
                    case .failure:
                        XCTFail("Should not fail")
                    }
                    expectation.fulfill()
                }
            )
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(attemptCount, 1)
    }

    func testAttemptSuccessAfterRetries() {
        let expectation = self.expectation(description: "Task should succeed after retries")
        var attemptCount = 0

        dispatchQueue.async { [weak self] in
            // Fail twice, succeed on the 3rd time
            self?.retrier.attempt(
                task: { (completion: @escaping (Result<String, Error>) -> Void) in
                    attemptCount += 1
                    if attemptCount < 3 {
                        completion(.failure(NSError(domain: "test", code: 500, userInfo: nil)))
                    } else {
                        completion(.success("Success"))
                    }
                },
                condition: { _ in true },
                maxAttempts: 5,
                completion: { result in
                    switch result {
                    case .success(let value):
                        XCTAssertEqual(value, "Success")
                    case .failure:
                        XCTFail("Should not fail eventually")
                    }
                    expectation.fulfill()
                }
            )
        }

        // Timeout needs to be long enough to account for backoff delays (1s + 2s = 3s total delay before 3rd attempt)
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(attemptCount, 3)
    }

    func testAttemptFailureAfterMaxAttempts() {
        let expectation = self.expectation(description: "Task should fail after max attempts")
        var attemptCount = 0
        let expectedError = NSError(domain: "test", code: 500, userInfo: nil)

        dispatchQueue.async { [weak self] in
            self?.retrier.attempt(
                // Explicitly define type so compiler knows T is String
                task: { (completion: @escaping (Result<String, Error>) -> Void) in
                    attemptCount += 1
                    completion(.failure(expectedError))
                },
                condition: { _ in true },
                maxAttempts: 3,
                completion: { result in
                    switch result {
                    case .success:
                        XCTFail("Should not succeed")
                    case .failure(let error):
                        XCTAssertEqual((error as NSError).code, 500)
                    }
                    expectation.fulfill()
                }
            )
        }

        // Delays: 1s (after 1st fail) + 2s (after 2nd fail) = 3s total.
        // Wait slightly longer to ensure completion is called.
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(attemptCount, 3)
    }

    func testAttemptFailureImmediatelyIfConditionNotMet() {
        let expectation = self.expectation(description: "Task should fail immediately if condition is false")
        var attemptCount = 0
        // Error code 400 usually implies client error, shouldn't retry
        let fatalError = NSError(domain: "test", code: 400, userInfo: nil)

        dispatchQueue.async { [weak self] in
            self?.retrier.attempt(
                // Explicitly define type so compiler knows T is String
                task: { (completion: @escaping (Result<String, Error>) -> Void) in
                    attemptCount += 1
                    completion(.failure(fatalError))
                },
                condition: { error in
                    // Only retry for 500 errors
                    (error as NSError).code == 500
                },
                maxAttempts: 3,
                completion: { result in
                    switch result {
                    case .success:
                        XCTFail("Should not succeed")
                    case .failure(let error):
                        XCTAssertEqual((error as NSError).code, 400)
                    }
                    expectation.fulfill()
                }
            )
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(attemptCount, 1) // Should only try once
    }

    func testRetrierDeallocationStopsRetries() {
        let expectation = self.expectation(description: "Retry should stop when Retrier is deallocated")
        var attemptCount = 0

        var retrier: Retrier? = Retrier(queue: dispatchQueue)

        dispatchQueue.async {
            retrier?.attempt(
                task: { (completion: @escaping (Result<String, Error>) -> Void) in
                    attemptCount += 1
                    completion(.failure(NSError(domain: "test", code: 499, userInfo: nil)))
                },
                condition: { _ in true },
                maxAttempts: 5,
                completion: { _ in
                    // Should not be called if retrier is deallocated
                }
            )
        }

        // Deallocate retrier after first attempt
        dispatchQueue.asyncAfter(deadline: .now() + 0.5) {
            retrier = nil
        }

        // Wait and verify retries stopped
        dispatchQueue.asyncAfter(deadline: .now() + 5.0) {
            XCTAssertEqual(attemptCount, 1, "Should only attempt once before deallocation")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }
}
