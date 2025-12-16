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

    // Verify that ApiClientImpl fails with .unacceptableCode (499) should be retriable at least 3 times
    // List test cases with different body responses

    // MARK: - Test Case 1: Retriable with 499 - Empty String Response
    func testRetriableWith499StatusCode_EmptyString() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                requestCount += 1
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
            },
            data: Data("".utf8),
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 499,
                httpVersion: nil,
                headerFields: nil
            )
        )

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should retry 3 times for 499 empty string")

        api.send(
            requestBody: MockRequestBody(),
            path: path,
            timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
            // Should fail after 3 attempts
            switch result {
            case .success((_, _)):
                XCTFail("should not succeed")
            case .failure(let error):
                guard let error = error as? ResponseError,
                      case .unacceptableCode(let code, _) = error, code == 499 else {
                    XCTFail("should be 499 unacceptable code error")
                    return
                }
                // Verify we attempted 3 times
                XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times for 499")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 2: Retriable with 499 - Random String Response
    func testRetriableWith499StatusCode_RandomString() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
            data: Data("okay random string".utf8),
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should retry 3 times for 499 random string")

        api.send(
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
                XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times for 499")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 3: Retriable with 499 - Nil Body Response
    func testRetriableWith499StatusCode_NilBody() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
            data: nil,
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should retry 3 times for 499 nil body")

        api.send(
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
                XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times for 499")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 4: Retriable with 499 - Valid JSON Response
    func testRetriableWith499StatusCode_ValidJSON() throws {
        let mockDataResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should retry 3 times for 499 valid JSON")

        api.send(
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
                XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times for 499")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 5: Non-Retriable with 300 Status Code
    func testNonRetriableStatusCode_300() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should NOT retry for 300 (only 499 is retriable)")

        api.send(
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
                XCTAssertEqual(requestCount, 1, "Should only attempt once for 300 (not retriable)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 6: Non-Retriable with 400 Status Code
    func testNonRetriableStatusCode_400() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should NOT retry for 400 (only 499 is retriable)")

        api.send(
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
                XCTAssertEqual(requestCount, 1, "Should only attempt once for 400 (not retriable)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 7: Non-Retriable with 500 Status Code
    func testNonRetriableStatusCode_500() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should NOT retry for 500 (only 499 is retriable)")

        api.send(
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
                XCTAssertEqual(requestCount, 1, "Should only attempt once for 500 (not retriable)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 8: Successful Response Should Not Retry
    func testSuccessStatusCode_DoesNotRetry() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        let session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Successful response should only attempt once")

        api.send(
            requestBody: MockRequestBody(),
            path: path,
            timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success((let response, _)):
                XCTAssertEqual(response.value, "response")
                // Should only attempt once (success on first try)
                XCTAssertEqual(requestCount, 1, "Should only attempt once for 200 success")
            case .failure(let error):
                XCTFail("should not fail: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 9: Comprehensive Test - All 499 Response Types Combined
    func testRetriableWith499StatusCode_AllCases() throws {
        let mockDataResponse = try JSONEncoder().encode(MockResponse())

        let cases = [
            ("empty string", Data("".utf8)),
            ("random string", Data("okay random string".utf8)),
            ("nil body", Data()),
            ("valid JSON", mockDataResponse)
        ]

        var expectations = [XCTestExpectation]()

        for (caseName, data) in cases {
            let expectation = XCTestExpectation(description: "Should retry 3 times for 499 - \(caseName)")

            let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
            let path = "path"
            let apiKey = "x:api-key"

            var requestCount = 0

            let session = MockSession(
                configuration: .default,
                requestHandler: { _ in
                    requestCount += 1
                },
                data: data,
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
                defaultRequestTimeoutMills: 200,
                session: session,
                logger: nil
            )

            api.send(
                requestBody: MockRequestBody(),
                path: path,
                timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success((_, _)):
                    XCTFail("should not succeed for \(caseName)")
                case .failure(let error):
                    guard let error = error as? ResponseError,
                          case .unacceptableCode(let code, _) = error, code == 499 else {
                        XCTFail("should be 499 unacceptable code error for \(caseName)")
                        return
                    }
                    XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times for 499 - \(caseName)")
                }
                expectation.fulfill()
            }

            expectations.append(expectation)
        }

        wait(for: expectations, timeout: 10)
    }

    // MARK: - Test Case 10: Sequential Status Codes - 499, then 4xx
    func testSequentialStatusCodes_499_Then_4xx() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        var session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 2 times: 499, then 4xx")

        api.send(
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
                XCTAssertEqual(requestCount, 2, "Should attempt exactly 2 times: 499 then 4xx")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 11: Sequential Status Codes - 499, then 2xx (success)
    func testSequentialStatusCodes_499_Then_2xx() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        var session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 2 times: 499, then 200 (success)")

        api.send(
            requestBody: MockRequestBody(),
            path: path,
            timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success((let response, _)):
                XCTAssertEqual(response.value, "response")
                XCTAssertEqual(requestCount, 2, "Should attempt exactly 2 times: 499 then 200")
            case .failure(let error):
                XCTFail("should not fail: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 12: Sequential Status Codes - 499, 499, then 4xx
    func testSequentialStatusCodes_499_499_Then_4xx() throws {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        var session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 3 times: 499, 499, then 4xx")

        api.send(
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
                XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times: 499, 499, then 4xx")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Test Case 13: Sequential Status Codes - 499, 499, then 2xx (success)
    func testSequentialStatusCodes_499_499_Then_2xx() throws {
        let mockResponse = try JSONEncoder().encode(MockResponse())
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        var requestCount = 0

        var session = MockSession(
            configuration: .default,
            requestHandler: { _ in
                requestCount += 1
            },
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
            defaultRequestTimeoutMills: 200,
            session: session,
            logger: nil
        )

        let expectation = XCTestExpectation(description: "Should attempt 3 times: 499, 499, then 200 (success)")

        api.send(
            requestBody: MockRequestBody(),
            path: path,
            timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success((let response, _)):
                XCTAssertEqual(response.value, "response")
                XCTAssertEqual(requestCount, 3, "Should attempt exactly 3 times: 499, 499, then 200")
            case .failure(let error):
                XCTFail("should not fail: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }
}
// swiftlint:enable type_body_length file_length
