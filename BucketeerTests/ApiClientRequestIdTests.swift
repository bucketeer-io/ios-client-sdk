import XCTest
@testable import Bucketeer

final class ApiClientRequestIdTests: XCTestCase {

    // Helper mocks for this test suite
    struct MockRequestBody: Codable {
        var value = "body"
    }

    struct MockResponse: Codable {
        var value = "response"
    }

    func testOutdatedRequestIsCancelled() {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        // Define scenarios for both API paths that support request ID checking
        let scenarios: [(ApiPaths, (ApiClientImpl, UUID) -> Void)] = [
            (.registerEvents, { api, id in api.setRegisterEventsRequestId(id) }),
            (.getEvaluations, { api, id in api.setEvaluationsRequestId(id) })
        ]

        for (path, setRequestId) in scenarios {
            let expectation = XCTestExpectation(description: "Should cancel outdated request for \(path)")

            // The session handler fails the test if a network request is actually attempted.
            // The check happens before network execution, so this ensures we short-circuit correctly.
            let session = MockSession(
                configuration: .default,
                requestHandler: { _ in
                    XCTFail("Network request should NOT be executed for cancelled query: \(path)")
                }
            )

            let api = ApiClientImpl(
                apiEndpoint: apiEndpointURL,
                apiKey: apiKey,
                featureTag: "tag1",
                session: session,
                retrier: Retrier(queue: mockDispatchQueue),
                logger: nil
            )

            mockDispatchQueue.sync {
                let outdatedRequestId = UUID()
                let currentRequestId = UUID()

                // 1. Simulate that a newer request has already been registered in the client
                setRequestId(api, currentRequestId)

                // 2. Attempt to send a request associated with the `outdatedRequestId`.
                //    This effectively simulates a race condition where an older task
                //    starts executing after a new one has superseded it.
                api.send(
                    requestId: outdatedRequestId,
                    requestBody: MockRequestBody(),
                    path: path.rawValue,
                    timeoutMillis: 100
                ) { (result: Result<(MockResponse, URLResponse), Error>) in
                    switch result {
                    case .success:
                        XCTFail("The request should have failed")
                    case .failure(let error):
                        // 3. Verify it failed with the specific 'illegalState' error
                        guard let bktError = error as? BKTError,
                              case .illegalState(let message) = bktError else {
                            XCTFail("Expected BKTError.illegalState, got: \(error)")
                            return
                        }
                        XCTAssertEqual(message, "Request cancelled by newer execution")
                    }
                    expectation.fulfill()
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }

    func testGetEvaluationsUpdatesRequestId() {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")

        // We use a session that does nothing, as we only care about the pre-request ID setup
        let session = MockSession(configuration: .default)

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        mockDispatchQueue.sync {
            // 1. Set a known ID manually
            let oldRequestId = UUID()
            api.setEvaluationsRequestId(oldRequestId)

            // 2. Call the high-level method getEvaluations.
            // This should internally generate a NEW UUID and replace `oldRequestId`.
            // We use a dummy user.
            let user = User.mock1
            api.getEvaluations(
                user: user,
                userEvaluationsId: "test_id",
                timeoutMillis: 100,
                condition: UserEvaluationCondition(
                evaluatedAt: "11223000",
                userAttributesUpdated: true)) { _ in }

            // 3. Attempt to use the old ID via the low-level `send`.
            // It should now be rejected because getEvaluations() logic should have updated the internal ID.
            let expectation = XCTestExpectation(description: "Old ID should be cancelled after calling getEvaluations")
            api.send(
                requestId: oldRequestId,
                requestBody: MockRequestBody(),
                path: ApiPaths.getEvaluations.rawValue,
                timeoutMillis: 100
            ) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success:
                    XCTFail("Should not succeed with outdated ID")
                case .failure(let error):
                    guard let bktError = error as? BKTError,
                          case .illegalState(let message) = bktError else {
                        XCTFail("Expected illegalState error, got \(error)")
                        return
                    }
                    XCTAssertEqual(message, "Request cancelled by newer execution")
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }

    func testRegisterEventsUpdatesRequestId() {
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let apiKey = "x:api-key"
        let mockDispatchQueue = DispatchQueue(label: "test.queue")
        let session = MockSession(configuration: .default)

        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: apiKey,
            featureTag: "tag1",
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        mockDispatchQueue.sync {
            // 1. Set a known ID manually
            let oldRequestId = UUID()
            api.setRegisterEventsRequestId(oldRequestId)

            // 2. Call the high-level method registerEvents.
            // This should update the internal request ID.
            api.registerEvents(events: []) { _ in }

            // 3. Attempt to use the old ID via the low-level `send`.
            // It should now be rejected because registerEvents() logic should have updated the internal ID.
            let expectation = XCTestExpectation(description: "Old ID should be cancelled after calling registerEvents")
            api.send(
                requestId: oldRequestId,
                requestBody: MockRequestBody(),
                path: ApiPaths.registerEvents.rawValue,
                timeoutMillis: 100
            ) { (result: Result<(MockResponse, URLResponse), Error>) in
                switch result {
                case .success:
                    XCTFail("Should not succeed with outdated ID")
                case .failure(let error):
                    guard let bktError = error as? BKTError,
                          case .illegalState(let message) = bktError else {
                        XCTFail("Expected illegalState error, got \(error)")
                        return
                    }
                    XCTAssertEqual(message, "Request cancelled by newer execution")
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
}
