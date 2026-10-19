import XCTest
@testable import Bucketeer

final class StreamHttpStatusTests: XCTestCase {

    // MARK: - isRecoverable

    func testIsRecoverableNilIsRecoverable() {
        XCTAssertTrue(StreamHttpStatus.isRecoverable(nil))
    }

    func testIsRecoverable5xxIsRecoverable() {
        for status in [500, 502, 503, 504] {
            XCTAssertTrue(StreamHttpStatus.isRecoverable(status), "status \(status)")
        }
    }

    func testIsRecoverableRetryable4xxIsRecoverable() {
        for status in [408, 429, 499] {
            XCTAssertTrue(StreamHttpStatus.isRecoverable(status), "status \(status)")
        }
    }

    func testIsRecoverableOther4xxIsNotRecoverable() {
        for status in [400, 401, 403, 404, 405, 413, 422] {
            XCTAssertFalse(StreamHttpStatus.isRecoverable(status), "status \(status)")
        }
    }

    // MARK: - isTerminal

    func testIsTerminalStatuses() {
        for status in [401, 403, 404, 405, 406, 410, 414, 415, 431, 451] {
            XCTAssertTrue(StreamHttpStatus.isTerminal(status), "status \(status)")
        }
    }

    func testIsNotTerminalStatuses() {
        let statuses: [Int?] = [nil, 400, 402, 408, 409, 413, 422, 428, 429, 500, 503]
        for status in statuses {
            XCTAssertFalse(StreamHttpStatus.isTerminal(status), "status \(String(describing: status))")
        }
    }

    // MARK: - Neither recoverable nor terminal (body-dependent statuses)

    // 400, 413, and 422 all depend on the request BODY (user attributes, cache state).
    // Not recoverable: a fast retry cannot change that state, it just resends the same
    // failing request. Not terminal either: unlike a fixed API key or URL, a later attempt
    // can genuinely differ once the app updates attributes or the cache refreshes.
    // Pinned explicitly so a future change to either predicate can't silently move one of
    // these into a category by accident.
    func testBodyDependentStatusesAreFalseForBothPredicates() {
        for status in [400, 413, 422] {
            XCTAssertFalse(StreamHttpStatus.isRecoverable(status), "isRecoverable \(status)")
            XCTAssertFalse(StreamHttpStatus.isTerminal(status), "isTerminal \(status)")
        }
    }
}
