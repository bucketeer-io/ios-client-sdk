import XCTest
@testable import Bucketeer

final class BKTUserTests: XCTestCase {

    func testUserIdRequiredUsingBuilder() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 1
        let builders = [
            BKTUser.Builder()
                .with(id: ""),
            BKTUser.Builder()
                .with(id: "user-id"),
            BKTUser.Builder()
                .with(id: "user-id")
                .with(attributes: [:])
        ]

        builders.forEach { builder in
            do {
                _ = try builder.build()
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("The user id is required.", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
        wait(for: [expectation], timeout: 0.1)
    }

    func testUserIdRequired() {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 1
        let userIds = [
            "",
            "user-id"
        ]

        userIds.forEach { userId in
            do {
                _ = try BKTUser(id: userId, attributes: [:])
            } catch BKTError.illegalArgument(let message) {
                XCTAssertEqual("The user id is required.", message)
                expectation.fulfill()
            } catch {
                print("Unexpected error: \(error).")
                XCTFail("Unexpected error: \(error).")
            }
        }
        wait(for: [expectation], timeout: 0.1)
    }
}
