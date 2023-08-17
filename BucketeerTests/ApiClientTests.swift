import XCTest
@testable import Bucketeer

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class ApiClientTests: XCTestCase {

    // MARK: - getEvaluations

    func testGetEvaluationsSuccess() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let userEvaluationsId: String = "user_evaluation1"
        let evaluations: [Evaluation] = [.mock1, .mock2]
        let response = GetEvaluationsResponse(
            evaluations: .init(
                id: userEvaluationsId,
                evaluations: evaluations
            ),
            userEvaluationsId: userEvaluationsId
        )
        let data = try JSONEncoder().encode(response)
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "get_evaluations"
        let apiKey = "x:api-key"
        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.url?.path, "/\(path)")
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "sourceId" : 2,
  "tag" : "tag1",
  "user" : {
    "data" : {
      "age" : "28"
    },
    "id" : "user1"
  },
  "userEvaluationsId" : "user_evaluation1"
}
"""
                XCTAssertEqual(jsonString, expected)
                expectation.fulfill()
            },
            data: data,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.getEvaluations(
            user: .mock1,
            userEvaluationsId: userEvaluationsId) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.evaluations.evaluations, evaluations)
                XCTAssertEqual(response.evaluations.id, userEvaluationsId)
                XCTAssertEqual(response.userEvaluationsId, userEvaluationsId)
                XCTAssertNotEqual(response.seconds, 0)
                XCTAssertNotEqual(response.sizeByte, 0)
                XCTAssertEqual(response.featureTag, "tag1")
            case .failure(let error, _):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testGetEvaluationsErrorBody() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let userEvaluationsId: String = "user_evaluation1"
        let errorResponse = ErrorResponse(error: .init(code: 400, message: "invalid parameter"))
        let data = try JSONEncoder().encode(errorResponse)
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "get_evaluations"
        let apiKey = "x:api-key"
        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.url?.path, "/\(path)")
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "sourceId" : 2,
  "tag" : "tag1",
  "user" : {
    "data" : {
      "age" : "28"
    },
    "id" : "user1"
  },
  "userEvaluationsId" : "user_evaluation1"
}
"""
                XCTAssertEqual(jsonString, expected)
                expectation.fulfill()
            },
            data: data,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.getEvaluations(
            user: .mock1,
            userEvaluationsId: userEvaluationsId) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error, let featureTag):
                XCTAssertEqual(error, .badRequest(message: "invalid parameter"))
                XCTAssertEqual(featureTag, "tag1")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - registerEvents

    func testRegisterEventsSuccess() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let events: [Event] = [.mockGoal1, .mockEvaluation1]
        let errors: [String: RegisterEventsResponse.ErrorResponse] = [
            Event.mockEvaluation1.id: .init(retriable: true, message: "error")
        ]
        let response = RegisterEventsResponse(errors: errors)
        let data = try JSONEncoder().encode(response)
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "register_events"
        let apiKey = "x:api-key"
        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.url?.path, "/\(path)")
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "events" : [
    {
      "event" : {
        "@type" : "type.googleapis.com/bucketeer.event.client.GoalEvent",
        "goalId" : "goal1",
        "metadata" : {
          "app_version" : "1.2.3",
          "device_model" : "iPhone14,7",
          "device_type" : "mobile",
          "os_version" : "16.0"
        },
        "sdkVersion" : "0.0.1",
        "sourceId" : 2,
        "tag" : "tag1",
        "timestamp" : 1,
        "user" : {
          "data" : {
            "age" : "28"
          },
          "id" : "user1"
        },
        "userId" : "user1",
        "value" : 1
      },
      "id" : "goal_event1",
      "type" : 1
    },
    {
      "event" : {
        "@type" : "type.googleapis.com/bucketeer.event.client.EvaluationEvent",
        "featureId" : "feature1",
        "featureVersion" : 1,
        "metadata" : {
          "app_version" : "1.2.3",
          "device_model" : "iPhone14,7",
          "device_type" : "mobile",
          "os_version" : "16.0"
        },
        "reason" : {
          "ruleId" : "rule1",
          "type" : "RULE"
        },
        "sdkVersion" : "0.0.1",
        "sourceId" : 2,
        "tag" : "tag1",
        "timestamp" : 1,
        "user" : {
          "data" : {
            "age" : "28"
          },
          "id" : "user1"
        },
        "userId" : "user1",
        "variationId" : "variation1"
      },
      "id" : "evaluation_event1",
      "type" : 3
    }
  ]
}
"""
                XCTAssertEqual(jsonString, expected)
                expectation.fulfill()
            },
            data: data,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.registerEvents(events: events) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.errors, errors)
            case .failure(let error):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }

    func testRegisterEventsErrorBody() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let events: [Event] = [.mockGoal1, .mockEvaluation1]
        let errorResponse = ErrorResponse(error: .init(code: 400, message: "invalid parameter"))
        let data = try JSONEncoder().encode(errorResponse)
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "register_events"
        let apiKey = "x:api-key"
        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.url?.path, "/\(path)")
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "events" : [
    {
      "event" : {
        "@type" : "type.googleapis.com/bucketeer.event.client.GoalEvent",
        "goalId" : "goal1",
        "metadata" : {
          "app_version" : "1.2.3",
          "device_model" : "iPhone14,7",
          "device_type" : "mobile",
          "os_version" : "16.0"
        },
        "sdkVersion" : "0.0.1",
        "sourceId" : 2,
        "tag" : "tag1",
        "timestamp" : 1,
        "user" : {
          "data" : {
            "age" : "28"
          },
          "id" : "user1"
        },
        "userId" : "user1",
        "value" : 1
      },
      "id" : "goal_event1",
      "type" : 1
    },
    {
      "event" : {
        "@type" : "type.googleapis.com/bucketeer.event.client.EvaluationEvent",
        "featureId" : "feature1",
        "featureVersion" : 1,
        "metadata" : {
          "app_version" : "1.2.3",
          "device_model" : "iPhone14,7",
          "device_type" : "mobile",
          "os_version" : "16.0"
        },
        "reason" : {
          "ruleId" : "rule1",
          "type" : "RULE"
        },
        "sdkVersion" : "0.0.1",
        "sourceId" : 2,
        "tag" : "tag1",
        "timestamp" : 1,
        "user" : {
          "data" : {
            "age" : "28"
          },
          "id" : "user1"
        },
        "userId" : "user1",
        "variationId" : "variation1"
      },
      "id" : "evaluation_event1",
      "type" : 3
    }
  ]
}
"""
                XCTAssertEqual(jsonString, expected)
                expectation.fulfill()
            },
            data: data,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(path),
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.registerEvents(events: events) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                XCTAssertEqual(error, .badRequest(message: "invalid parameter"))
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - send

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

    func testSendSuccess() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()
        let mockResponse = MockResponse()
        let data = try JSONEncoder().encode(mockResponse)

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                XCTAssertEqual(request.timeoutInterval, 30)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                XCTAssertEqual(jsonString, expected)
                expectation.fulfill()
            },
            data: data,
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
            session: session,
            logger: nil
        )
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success((let response, _)):
                XCTAssertEqual(response, mockResponse)
            case .failure(let error):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testSendSuccessWithDefaultTimeout() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()
        let mockResponse = MockResponse()
        let data = try JSONEncoder().encode(mockResponse)

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                XCTAssertEqual(request.timeoutInterval, 0.2)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                XCTAssertEqual(jsonString, expected)
                expectation.fulfill()
            },
            data: data,
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
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: 200) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success((let response, _)):
                XCTAssertEqual(response, mockResponse)
            case .failure(let error):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testSendSuccessWithCustomTimeout() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()
        let mockResponse = MockResponse()
        let data = try JSONEncoder().encode(mockResponse)

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                XCTAssertEqual(request.timeoutInterval, 0.1)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                expectation.fulfill()
            },
            data: data,
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
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: 100) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success((let response, _)):
                XCTAssertEqual(response, mockResponse)
            case .failure(let error):
                XCTFail("\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testTaskFailureWithoutError() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                XCTAssertEqual(request.timeoutInterval, 30)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                expectation.fulfill()
            },
            data: nil,
            response: nil,
            error: nil
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                guard
                    let error = error as? ResponseError,
                    case .unknown(let urlResponse) = error else {
                    XCTFail()
                    return
                }
                XCTAssertNil(urlResponse)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testTaskFailureWithSomeError() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                XCTAssertEqual(request.timeoutInterval, 30)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                expectation.fulfill()
            },
            data: nil,
            response: nil,
            error: SomeError.failed
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                guard let error = error as? SomeError else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(error, .failed)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testTaskFailureNoURLResponseError() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()
        let mockResponse = MockResponse()
        let data = try JSONEncoder().encode(mockResponse)

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                XCTAssertEqual(request.timeoutInterval, 30)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                expectation.fulfill()
            },
            data: data,
            response: nil,
            error: nil
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                guard
                    let error = error as? ResponseError,
                    case .unknown(let urlResponse) = error else {
                    XCTFail()
                    return
                }
                XCTAssertNil(urlResponse)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testTaskFailureWithUnexpectedErrorResponse() throws {
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        let mockRequestBody = MockRequestBody()
        let mockResponse = MockResponse()
        let data = try JSONEncoder().encode(mockResponse)

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: { request in
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.host, apiEndpointURL.host)
                XCTAssertEqual(request.url?.path, "/\(path)")
                XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], apiKey)
                let data = request.httpBody ?? Data()
                let jsonString = String(data: data, encoding: .utf8) ?? ""
                let expected = """
{
  "value" : "body"
}
"""
                expectation.fulfill()
            },
            data: data,
            response: .init(
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
            session: session,
            logger: nil
        )
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                guard
                    let error = error as? DecodingError,
                    case .keyNotFound(let codingKey, _) = error else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(codingKey.stringValue, "error")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testTaskFailureWithRequestBodyEncodingError() throws {
        let expectation = XCTestExpectation()

        let mockRequestBody = MockInvalidRequestBody()

        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let path = "path"
        let apiKey = "x:api-key"

        let session = MockSession(
            configuration: .default,
            requestHandler: nil,
            data: nil,
            response: nil,
            error: nil
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            logger: nil
        )
        api.send(
            requestBody: mockRequestBody,
            path: path,
            timeoutMillis: ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS) { (result: Result<(MockResponse, URLResponse), Error>) in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                guard let error = error as? SomeError else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(error, .failed)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
