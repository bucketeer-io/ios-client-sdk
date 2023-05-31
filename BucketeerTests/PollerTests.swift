import XCTest
@testable import Bucketeer

class PollerTests: XCTestCase {
    func testStartNotOnMainThread() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 10
        let dispatchQueue = DispatchQueue(label: "default", qos: .default)
        let logger = MockLogger()
        var count: Int = 0

        let poller = Poller(
            intervalMillis: 10,
            queue: dispatchQueue,
            logger: logger
        ) { [weak logger] poller in
            XCTAssert(!Thread.isMainThread)
            XCTAssertEqual(logger?.debugMessage, nil)
            guard count < 10 else {
                poller.stop()
                return
            }
            expectation.fulfill()
            count += 1
        }
        poller.start()
        wait(for: [expectation], timeout: 1)
    }

    func testStartWithReset() {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let dispatchQueue = DispatchQueue(label: "default", qos: .default)
        let logger = MockLogger()
        var count: Int = 0

        let poller = Poller(
            intervalMillis: 50,
            queue: dispatchQueue,
            logger: logger
        ) { [weak logger] poller in
            XCTAssert(!Thread.isMainThread)
            if count == 0 {
                XCTAssertEqual(logger?.debugMessage, nil)
                poller.start() // duplicate started
            } else if count == 1 {
                XCTAssertEqual(logger?.debugMessage, "reset poller")
            } else {
                poller.stop()
                return
            }
            count += 1
            expectation.fulfill()
        }
        poller.start()
        wait(for: [expectation], timeout: 1)
    }

    func testStop() {
        let expectation = self.expectation(description: "")
        expectation.isInverted = true
        let dispatchQueue = DispatchQueue(label: "default", qos: .default)
        let logger = MockLogger()

        let poller = Poller(
            intervalMillis: 50,
            queue: dispatchQueue,
            logger: logger
        ) { _ in
            expectation.fulfill()
        }
        poller.start()
        poller.stop()
        wait(for: [expectation], timeout: 1)
    }
}
