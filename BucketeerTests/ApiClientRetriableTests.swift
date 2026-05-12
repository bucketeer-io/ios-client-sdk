import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length file_length
class ApiClientRetriableTests: XCTestCase {
    enum SomeError: Error, Equatable {
        case failed
    }
    struct MockRequestBody: Codable, Hashable {
        var value = "body"
    }
    struct MockInvalidRequestBody: Codable, Hashable {
        var value = "body"

        func encode(to encoder: Encoder) throws {
            throw SomeError.failed
        }
    }
    struct MockResponse: Codable, Hashable {
        var value = "response"
    }

    // Verify that ApiClientImpl fails with .unacceptableCode (499) should be retriable 3 times
    // List test cases with different body responses

    // MARK: - Test Case: Retriable with 499 - Valid JSON Response
    func testRetriableWith499StatusCode() throws {
        let mockDataResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        let session = MockSession(
            configuration: .default,
            data: mockDataResponse,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should retry 3 times for 499 valid JSON")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success((_, _)):
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 499 else {
                        XCTFail("should be 499 unacceptable code error")
                        return
                    }
                    XCTAssertEqual(session.requestCount(), 4, "Should attempt exactly 4 times for 499")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 20)
    }

    // MARK: - Test Case: Non-Retriable with 300 Status Code
    func testNonRetriableStatusCode_300() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        let session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 300,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should NOT retry for 300 (only 499 is retriable)")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success((_, _)):
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 300 else {
                        XCTFail("should be 300 unacceptable code error")
                        return
                    }
                    // Should only attempt once (no retry for 300)
                    XCTAssertEqual(session.requestCount(), 1, "Should only attempt once for 300 (not retriable)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Non-Retriable with 400 Status Code
    func testNonRetriableStatusCode_400() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        let session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should NOT retry for 400 (only 499 is retriable)")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success((_, _)):
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 400 else {
                        XCTFail("should be 400 unacceptable code error")
                        return
                    }
                    // Should only attempt once (no retry for 400)
                    XCTAssertEqual(session.requestCount(), 1, "Should only attempt once for 400 (not retriable)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Non-Retriable with 500 Status Code
    func testNonRetriableStatusCode_500() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        let session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should NOT retry for 500 (only 499 is retriable)")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success((_, _)):
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 500 else {
                        XCTFail("should be 500 unacceptable code error")
                        return
                    }
                    // Should only attempt once (no retry for 500)
                    XCTAssertEqual(session.requestCount(), 1, "Should only attempt once for 500 (not retriable)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Successful Response Should Not Retry
    func testSuccessStatusCode_DoesNotRetry() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        let session = MockSession(
            configuration: .default,
            data: mockResponse,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Successful response should only attempt once")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success((let response, _)):
                        XCTAssertEqual(response.value, "response")
                        // Should only attempt once (success on first try)
                        XCTAssertEqual(session.requestCount(), 1, "Should only attempt once for 200 success")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Sequential Status Codes - 499, then 4xx
    func testSequentialStatusCodes_499_Then_4xx() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // Use responseProvider to return different responses based on requestCount
        session.responseProvider = { _, count in
            let statusCode = count == 1 ? 499 : 400
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: Data("".utf8), response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 2 times: 499, then 4xx")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success:
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 400 else {
                        XCTFail("should be 400 unacceptable code error")
                        return
                    }
                    XCTAssertEqual(session.requestCount(), 2, "Should attempt exactly 2 times: 499 then 4xx")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Sequential Status Codes - 499, then 2xx (success)
    func testSequentialStatusCodes_499_Then_2xx() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // Use responseProvider to return different responses based on requestCount
        session.responseProvider = { _, count in
            let statusCode = count == 1 ? 499 : 200
            let responseData = count == 1 ? Data("".utf8) : mockResponse
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: responseData, response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 2 times: 499, then 200 (success)")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success((let response, _)):
                        XCTAssertEqual(response.value, "response")
                        XCTAssertEqual(session.requestCount(), 2, "Should attempt exactly 2 times: 499 then 200")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Sequential Status Codes - 499, 499, then 4xx
    func testSequentialStatusCodes_499_499_Then_4xx() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // Use responseProvider to return different responses based on requestCount
        session.responseProvider = { _, count in
            let statusCode = count < 3 ? 499 : 400
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: Data("".utf8), response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 3 times: 499, 499, then 4xx")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success:
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 400 else {
                        XCTFail("should be 400 unacceptable code error")
                        return
                    }
                    XCTAssertEqual(session.requestCount(), 3, "Should attempt exactly 3 times: 499, 499, then 4xx")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Sequential Status Codes - 499, 499, then 2xx (success)
    func testSequentialStatusCodes_499_499_Then_2xx() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // Use responseProvider to return different responses based on requestCount
        session.responseProvider = { _, count in
            let statusCode = count < 3 ? 499 : 200
            let responseData = count < 3 ? Data("".utf8) : mockResponse
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: responseData, response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 3 times: 499, 499, then 200 (success)")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success((let response, _)):
                        XCTAssertEqual(response.value, "response")
                        XCTAssertEqual(session.requestCount(), 3, "Should attempt exactly 3 times: 499, 499, then 200")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case: Sequential Status Codes - 499, 499, 499 then 4xx
    func testSequentialStatusCodes_499_499_499_Then_4xx() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // Use responseProvider to return different responses based on requestCount
        session.responseProvider = { _, count in
            let statusCode = count < 4 ? 499 : 400
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: Data("".utf8), response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 4 times: 499, 499, 499, then 4xx")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success:
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 400 else {
                        XCTFail("should be 400 unacceptable code error")
                        return
                    }
                    XCTAssertEqual(session.requestCount(), 4, "Should attempt exactly 4 times: 499, 499, 499, then 4xx")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 15)
    }

    // MARK: - Test Case: Sequential Status Codes - 499, 499, 499 then 2xx
    func testSequentialStatusCodes_499_499_499_Then_2xx() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // Use responseProvider to return different responses based on requestCount
        session.responseProvider = { _, count in
            let statusCode = count < 4 ? 499 : 200
            let responseData = count < 4 ? Data("".utf8) : mockResponse
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: responseData, response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 4 times: 499, 499, 499, then 200 (success)")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success((let response, _)):
                        XCTAssertEqual(response.value, "response")
                        XCTAssertEqual(session.requestCount(), 4, "Should attempt exactly 4 times: 499, 499, 499, then 200")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
        }

        wait(for: [expectation], timeout: 15)
    }

    // MARK: - Test Case: Cancel Ongoing Request During Retry
    func testCancelOngoingRequestDuringRetry() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )

        // First request returns 499, second should not happen due to cancellation
        var requestAttempts = 0
        session.responseProvider = { _, count in
            requestAttempts = count
            let response = HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            )
            return MockResponseData(data: Data("".utf8), response: response, error: nil)
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should fail with illegalState after client is closed")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success:
                    XCTFail("should not succeed")
                case .failure(let error):
                    guard let error = error as? BKTError,
                          case .illegalState(let message) = error else {
                        XCTFail("should be BKTError.illegalState, got: \(error)")
                        return
                    }
                    XCTAssertEqual(message, "API Client has been closed")
                    // 1 for the first attempt
                    // 2 for the next attempt but got cancelled
                    XCTAssertEqual(requestAttempts, 2, "Should attempt 2 before cancellation")
                }
                expectation.fulfill()
            }
        }

        // Cancel after a brief delay to allow first request to complete
        mockDispatchQueue.asyncAfter(deadline: .now() + 2) {
            api.cancelAllOngoingRequest()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - onAttemptStart callback tests

    // callback fires exactly once when the first attempt succeeds
    func testOnAttemptStartCalledOnceWhenFirstAttemptSucceeds() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let mockDispatchQueue = DispatchQueue(label: "test.queue.tc1")

        var session = MockSession(
            configuration: .default,
            data: mockResponse,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        session.responseProvider = { _, _ in
            return MockResponseData(
                data: mockResponse,
                response: HTTPURLResponse(
                    url: apiEndpointURL.appendingPathComponent(path),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil
            )
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "onAttemptStart called once on first-attempt success")
        var callCount = 0

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100,
                onAttemptStart: { callCount += 1 },
                completion: { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success:
                        XCTAssertEqual(callCount, 1, "onAttemptStart should be called exactly once")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
            )
        }

        wait(for: [expectation], timeout: 2)
    }

    // callback fires once per attempt — 499 then 200 (2 calls total)
    func testOnAttemptStartCalledOncePerAttemptWith499ThenSuccess() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let mockDispatchQueue = DispatchQueue(label: "test.queue.tc2")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        session.responseProvider = { _, count in
            let statusCode = count == 1 ? 499 : 200
            let data = count == 1 ? Data("".utf8) : mockResponse
            return MockResponseData(
                data: data,
                response: HTTPURLResponse(
                    url: apiEndpointURL.appendingPathComponent(path),
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil
            )
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "onAttemptStart called twice for 499 then 200")
        var callCount = 0

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100,
                onAttemptStart: { callCount += 1 },
                completion: { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success:
                        XCTAssertEqual(callCount, 2, "onAttemptStart should be called once per attempt")
                        XCTAssertEqual(session.requestCount(), 2, "Should attempt exactly 2 times")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
            )
        }

        wait(for: [expectation], timeout: 5)
    }

    // callback fires once per attempt — 499, 499, then 200 (3 calls total)
    func testOnAttemptStartCalledOncePerAttemptWithMultipleRetries() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let mockDispatchQueue = DispatchQueue(label: "test.queue.tc3")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        session.responseProvider = { _, count in
            let statusCode = count < 3 ? 499 : 200
            let data = count < 3 ? Data("".utf8) : mockResponse
            return MockResponseData(
                data: data,
                response: HTTPURLResponse(
                    url: apiEndpointURL.appendingPathComponent(path),
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil
            )
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "onAttemptStart called three times for 499, 499, then 200")
        var callCount = 0

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100,
                onAttemptStart: { callCount += 1 },
                completion: { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success:
                        XCTAssertEqual(callCount, 3, "onAttemptStart should be called once per attempt")
                        XCTAssertEqual(session.requestCount(), 3, "Should attempt exactly 3 times")
                    case .failure(let error):
                        XCTFail("should not fail: \(error)")
                    }
                    expectation.fulfill()
                }
            )
        }

        wait(for: [expectation], timeout: 8)
    }

    // omitting onAttemptStart (default nil) does not crash or alter normal behaviour
    func testSendWorksNormallyWhenOnAttemptStartIsNil() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.registerEvents.rawValue
        let mockDispatchQueue = DispatchQueue(label: "test.queue.tc4")

        var session = MockSession(
            configuration: .default,
            data: mockResponse,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        session.responseProvider = { _, _ in
            return MockResponseData(
                data: mockResponse,
                response: HTTPURLResponse(
                    url: apiEndpointURL.appendingPathComponent(path),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil
            )
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "send works normally without onAttemptStart")

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setRegisterEventsRequestId(requestId)
            // No onAttemptStart passed — uses default nil
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100
            ) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success((let response, _)):
                    XCTAssertEqual(response.value, "response")
                    XCTAssertEqual(session.requestCount(), 1, "Should only attempt once")
                case .failure(let error):
                    XCTFail("should not fail: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2)
    }

    // onAttemptStart is NOT called for a retry that is cancelled by a newer request ID
    func testOnAttemptStartNotCalledWhenRequestCancelledByNewerExecution() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = ApiPaths.getEvaluations.rawValue
        let mockDispatchQueue = DispatchQueue(label: "test.queue.tc5")

        var session = MockSession(
            configuration: .default,
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
        session.responseProvider = { _, _ in
            return MockResponseData(
                data: Data("".utf8),
                response: HTTPURLResponse(
                    url: apiEndpointURL.appendingPathComponent(path),
                    statusCode: 499,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil
            )
        }

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: Version.current),
            defaultRequestTimeoutMillis: 200,
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        let expectation = XCTestExpectation(description: "onAttemptStart not called for cancelled retry")
        var callCount = 0

        mockDispatchQueue.async {
            let requestId = UUID()
            api.setEvaluationsRequestId(requestId)
            api.send(
                requestId: requestId,
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100,
                onAttemptStart: { callCount += 1 },
                completion: { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success:
                        XCTFail("should not succeed")
                    case .failure(let error):
                        guard let bktError = error as? BKTError,
                              case .illegalState(let message) = bktError else {
                            XCTFail("expected BKTError.illegalState, got: \(error)")
                            return
                        }
                        XCTAssertEqual(message, "Request cancelled by newer execution")
                        // Only the initial attempt should have fired onAttemptStart;
                        // the retry was cancelled before the callback was reached.
                        XCTAssertEqual(callCount, 1, "onAttemptStart must not be called for a cancelled retry")
                    }
                    expectation.fulfill()
                }
            )
        }

        // The first attempt fires and returns 499. Backoff takes ~1 s before the retry.
        // Update the request ID after 0.1 s so the retry sees a mismatch and cancels.
        mockDispatchQueue.asyncAfter(deadline: .now() + 0.1) {
            api.setEvaluationsRequestId(UUID())
        }

        wait(for: [expectation], timeout: 5)
    }
}
// swiftlint:enable type_body_length file_length
