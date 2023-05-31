import XCTest
@testable import Bucketeer

class BKTErrorTests: XCTestCase {
    enum SomeError: Error {
        case a
        case b
    }
    func assertEqual(_ a: BKTError, _ b: BKTError) {
        XCTAssertEqual(a, b)
    }

    func assertNotEqual(_ a: BKTError, _ b: BKTError) {
        XCTAssertNotEqual(a, b)
    }

    func testEquatable() {
        // equal
        assertEqual(.badRequest(message: "1"), .badRequest(message: "1"))
        assertEqual(.unauthorized(message: "1"), .unauthorized(message: "1"))
        assertEqual(.forbidden(message: "1"), .forbidden(message: "1"))
        assertEqual(.notFound(message: "1"), .notFound(message: "1"))
        assertEqual(.clientClosed(message: "1"), .clientClosed(message: "1"))
        assertEqual(.unavailable(message: "1"), .unavailable(message: "1"))
        assertEqual(.apiServer(message: "1"), .apiServer(message: "1"))
        assertEqual(
            .timeout(message: "1", error: SomeError.a),
            .timeout(message: "1", error: SomeError.a)
        )
        assertEqual(
            .network(message: "1", error: SomeError.a),
            .network(message: "1", error: SomeError.a)
        )
        assertEqual(.illegalArgument(message: "1"), .illegalArgument(message: "1"))
        assertEqual(.illegalState(message: "1"), .illegalState(message: "1"))
        assertEqual(
            .unknownServer(message: "1", error: SomeError.a),
            .unknownServer(message: "1", error: SomeError.a)
        )
        assertEqual(
            .unknown(message: "1", error: SomeError.a),
            .unknown(message: "1", error: SomeError.a)
        )

        // equal with diffrent error
        assertEqual(
            .timeout(message: "1", error: SomeError.a),
            .timeout(message: "1", error: SomeError.b)
        )
        assertEqual(
            .network(message: "1", error: SomeError.a),
            .network(message: "1", error: SomeError.b)
        )
        assertEqual(
            .unknownServer(message: "1", error: SomeError.a),
            .unknownServer(message: "1", error: SomeError.b)
        )
        assertEqual(
            .unknown(message: "1", error: SomeError.a),
            .unknown(message: "1", error: SomeError.b)
        )

        // not equal
        assertNotEqual(.badRequest(message: "1"), .badRequest(message: "2"))
        assertNotEqual(.unauthorized(message: "1"), .unauthorized(message: "2"))
        assertNotEqual(.forbidden(message: "1"), .forbidden(message: "2"))
        assertNotEqual(.notFound(message: "1"), .notFound(message: "2"))
        assertNotEqual(.clientClosed(message: "1"), .clientClosed(message: "2"))
        assertNotEqual(.unavailable(message: "1"), .unavailable(message: "2"))
        assertNotEqual(.apiServer(message: "1"), .apiServer(message: "2"))
        assertNotEqual(
            .timeout(message: "1", error: SomeError.a),
            .timeout(message: "2", error: SomeError.a)
        )
        assertNotEqual(
            .network(message: "1", error: SomeError.a),
            .network(message: "2", error: SomeError.a)
        )
        assertNotEqual(.illegalArgument(message: "1"), .illegalArgument(message: "2"))
        assertNotEqual(.illegalState(message: "1"), .illegalState(message: "2"))
        assertNotEqual(
            .unknownServer(message: "1", error: SomeError.a),
            .unknownServer(message: "2", error: SomeError.a)
        )
        assertNotEqual(
            .unknown(message: "1", error: SomeError.a),
            .unknown(message: "2", error: SomeError.a)
        )
    }

    func testInitWithBKTError() {
        let error = BKTError.badRequest(message: "m1")
        assertEqual(error, .init(error: error))
    }

    func testInitWithResponseError() {
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 400, response: nil)),
            .badRequest(message: "BadRequest error")
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 401, response: nil)),
            .unauthorized(message: "Unauthorized error")
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 403, response: nil)),
            .forbidden(message: "Forbidden error")
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 404, response: nil)),
            .notFound(message: "NotFound error")
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 499, response: nil)),
            .clientClosed(message: "Client Closed Request error")
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 500, response: nil)),
            .apiServer(message: "InternalServer error")
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 503, response: nil)),
            .unavailable(message: "Unavailable error")
        )
        let errorResponse = ErrorResponse(error: .init(code: 450, message: "some error"))
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 450, response: errorResponse)),
            .unknownServer(message: "Unknown server error: [450] some error", error: SomeError.a)
        )
        assertEqual(
            .init(error: ResponseError.unacceptableCode(code: 450, response: nil)),
            .unknownServer(message: "Unknown server error: no error body", error: SomeError.a)
        )

        assertEqual(
            .init(error: ResponseError.unknown(nil)),
            .network(message: "Network connection error: no response", error: SomeError.a)
        )

        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://test.bucketeer.io")!,
            statusCode: 600,
            httpVersion: nil,
            headerFields: [:]
        )!
        assertEqual(
            .init(error: ResponseError.unknown(urlResponse)),
            .network(message: "Network connection error: [600] \(urlResponse)", error: SomeError.a)
        )

        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [:])
        assertEqual(
            .init(error: timeoutError),
            .timeout(message: "Request timeout error: \(timeoutError)", error: timeoutError)
        )

        let unknownError = NSError(domain: "unknown", code: 3000, userInfo: [:])
        assertEqual(
            .init(error: unknownError),
            .unknown(message: "Unknown error: \(unknownError)", error: unknownError)
        )
    }
}
