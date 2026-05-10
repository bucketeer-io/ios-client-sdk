import XCTest
@testable import Bucketeer

/// Regression tests for the "duration is nil and latencySecond is 0" backend
/// warning, applied to the iOS SDK.
///
/// The Node.js (`Date.now()`) and Android (`System.currentTimeMillis()`) SDKs
/// both produced `latencySecond: 0` in production because their timers had
/// only millisecond resolution and rounded sub-millisecond operations to 0.
///
/// The iOS SDK measures `seconds` with `Date().timeIntervalSince(...)`, where
/// `TimeInterval` is `Double` and `Date` is backed by sub-microsecond
/// precision (`CFAbsoluteTime`). These tests verify that the iOS code path
/// is *not* susceptible to the same rounding behaviour, both at the helper
/// level and end-to-end through `ApiClientImpl.getEvaluations`.
class ApiClientLatencyTests: XCTestCase {

    // MARK: - timer-level invariants

    /// Two consecutive `Date()` reads, separated by trivial work, must give
    /// a strictly positive `timeIntervalSince`. With `Date.now()` (Node) or
    /// `System.currentTimeMillis()` (Android) this assertion would fail
    /// most of the time on modern hardware; with `Date()` it must always
    /// pass because the underlying clock is sub-microsecond.
    func testTimeIntervalSinceIsStrictlyPositiveForFastWork() {
        var failingIndex: Int?
        var failingValue: TimeInterval = 0
        for i in 0..<1_000 {
            let start = Date()
            // mimic the kind of trivial work the SDK does between the two
            // `Date()` reads (object alloc, a few arithmetic ops). This
            // takes nanoseconds at most.
            _ = (0..<10).reduce(0, +)
            let elapsed = Date().timeIntervalSince(start)
            if elapsed <= 0 {
                failingIndex = i
                failingValue = elapsed
                break
            }
        }
        XCTAssertNil(
            failingIndex,
            "Date.timeIntervalSince must be > 0 for any real work; got \(failingValue) at iteration \(failingIndex ?? -1)"
        )
    }

    /// At least one of the samples should be < 1ms. The Node/Android timers
    /// could not satisfy this assertion at all; `Date.timeIntervalSince`
    /// must, because it is sub-microsecond.
    func testTimeIntervalSinceHasSubMillisecondResolution() {
        var sawSubMillisecond = false
        for _ in 0..<100 {
            let start = Date()
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 0 && elapsed < 0.001 {
                sawSubMillisecond = true
                break
            }
        }
        XCTAssertTrue(
            sawSubMillisecond,
            "expected at least one Date.timeIntervalSince() sample to measure < 1ms"
        )
    }

    // MARK: - SDK-level invariant: `getEvaluations` reports seconds > 0

    /// Mirrors the existing `testGetEvaluationsSuccess` happy-path
    /// assertion (`XCTAssertNotEqual(response.seconds, 0)`) but stresses
    /// it across many fast, instant mock responses. With the previous
    /// Node/Android-style `Date.now()` / `currentTimeMillis()` timers this
    /// loop would have shipped `seconds = 0` reliably; with iOS's
    /// `Date.timeIntervalSince` it must never do so, so the backend's
    /// `ev.Duration == nil && ev.LatencySecond == 0` check cannot fire.
    func testGetEvaluationsAlwaysReportsPositiveSecondsForFastResponses() throws {
        let userEvaluationsId = "user_evaluation1"
        let response = GetEvaluationsResponse(
            evaluations: .init(
                id: userEvaluationsId,
                evaluations: [.mock1, .mock2],
                createdAt: "11223344",
                forceUpdate: false,
                archivedFeatureIds: []
            ),
            userEvaluationsId: userEvaluationsId
        )
        let data = try JSONEncoder().encode(response)
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let mockDispatchQueue = DispatchQueue(label: "test.queue.latency")

        let session = MockSession(
            configuration: .default,
            requestHandler: nil,
            data: data,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(ApiPaths.getEvaluations.rawValue),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: "1.2.3"),
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        // Fire many requests back-to-back and verify every successful
        // response has `seconds > 0`. 50 iterations is enough to exercise
        // the timing path many times without slowing CI.
        let iterations = 50
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = iterations

        var observedSeconds: [TimeInterval] = []
        let observedSecondsLock = NSLock()

        for _ in 0..<iterations {
            mockDispatchQueue.async {
                api.getEvaluations(
                    user: .mock1,
                    userEvaluationsId: userEvaluationsId,
                    condition: UserEvaluationCondition(
                        evaluatedAt: "0",
                        userAttributesUpdated: false
                    )
                ) { result in
                    switch result {
                    case .success(let response):
                        observedSecondsLock.lock()
                        observedSeconds.append(response.seconds)
                        observedSecondsLock.unlock()
                    case .failure(let error, _):
                        XCTFail("unexpected failure: \(error)")
                    }
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(observedSeconds.count, iterations)
        for (i, seconds) in observedSeconds.enumerated() {
            XCTAssertGreaterThan(
                seconds,
                0,
                "ApiClientImpl.getEvaluations reported seconds == \(seconds) at iteration \(i); the backend would reject this as \"duration is nil and latencySecond is 0\""
            )
            XCTAssertTrue(
                seconds.isFinite,
                "seconds must be finite, got \(seconds) at iteration \(i)"
            )
        }
    }

    /// Confirms the SDK can actually measure a sub-millisecond round-trip.
    /// MockSession returns synchronously on a concurrent network queue, so
    /// the round-trip is dominated by dispatch overhead and frequently
    /// completes in well under 1 ms. With ms-precision timers this would
    /// have rounded to 0; with `Date.timeIntervalSince` it must measure
    /// > 0 and (often) < 1 ms.
    func testGetEvaluationsCanMeasureSubMillisecondRoundTrip() throws {
        let userEvaluationsId = "user_evaluation_sub_ms"
        let response = GetEvaluationsResponse(
            evaluations: .init(
                id: userEvaluationsId,
                evaluations: [.mock1],
                createdAt: "1",
                forceUpdate: false,
                archivedFeatureIds: []
            ),
            userEvaluationsId: userEvaluationsId
        )
        let data = try JSONEncoder().encode(response)
        let apiEndpointURL = URL(string: "https://test.bucketeer.io")!
        let mockDispatchQueue = DispatchQueue(label: "test.queue.subms")

        let session = MockSession(
            configuration: .default,
            requestHandler: nil,
            data: data,
            response: HTTPURLResponse(
                url: apiEndpointURL.appendingPathComponent(ApiPaths.getEvaluations.rawValue),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = ApiClientImpl(
            apiEndpoint: apiEndpointURL,
            apiKey: "x:api-key",
            featureTag: "tag1",
            sdkInfo: SDKInfo(sourceId: .ios, sdkVersion: "1.2.3"),
            session: session,
            retrier: Retrier(queue: mockDispatchQueue),
            logger: nil
        )

        // Many attempts; pass if at least one round-trip measures < 1 ms
        // AND > 0. We accept "any one" because CI machines vary; what we
        // care about is that the timer can resolve below the millisecond
        // threshold at all (which is what was missing on Android/Node).
        let iterations = 50
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = iterations

        var observed: [TimeInterval] = []
        let lock = NSLock()

        for _ in 0..<iterations {
            mockDispatchQueue.async {
                api.getEvaluations(
                    user: .mock1,
                    userEvaluationsId: userEvaluationsId,
                    condition: UserEvaluationCondition(
                        evaluatedAt: "0",
                        userAttributesUpdated: false
                    )
                ) { result in
                    if case .success(let response) = result {
                        lock.lock()
                        observed.append(response.seconds)
                        lock.unlock()
                    }
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5)

        let positiveSubMillisecond = observed.filter { $0 > 0 && $0 < 0.001 }
        XCTAssertFalse(
            positiveSubMillisecond.isEmpty,
            "expected at least one fast mock response to measure between 0 and 1ms; observed: \(observed)"
        )
    }
}
