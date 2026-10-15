import Foundation
import XCTest
@testable import Bucketeer

/// Streaming E2E tests that can see the network. The SDK is pointed at a proxy server inside
/// the test (`RecordingProxy`) through the public `apiEndpoint` setting; the proxy forwards
/// to the real backend and records every request. That lets these tests check that values
/// arrive over the stream, not through a REST fetch.
///
/// What they cannot see: the SDK's own connection to the real gateway (TLS, HTTP/2, the
/// gateway's chunking). `E2EStreamingDirectTests` runs the user-visible checks without the
/// proxy for that. See `BucketeerTests/E2E/README.md`.
@available(iOS 13, *)
final class E2EStreamingProxyTests: XCTestCase {
    private var proxy: RecordingProxy!

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults.removeAllEvaluationData()
        try? FileManager.default.removeItem(at: .database)

        let endpoint = ProcessInfo.processInfo.environment["E2E_API_ENDPOINT"]!
        proxy = try RecordingProxy(upstream: URL(string: endpoint)!)
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()

        try BKTClient.destroy()
        // After destroy(): traffic from the old stream is never counted in the next test.
        proxy?.stop()
        UserDefaults.removeAllEvaluationData()
        try? FileManager.default.removeItem(at: .database)
    }

    @MainActor
    func testStreamOpensAfterInit() async throws {
        try await BKTClient.initialize(config: config(), user: user())

        // The stream opens once the init fetch has finished. Waiting for its reply, not only
        // its request, means a 401 or a 404 never passes.
        await assertEventually(timeout: E2EStreamingTimeout.streamOpen, "the stream did not open; requests: \(proxy.records)") {
            self.streamOpenCount >= 1
        }

        // The init fetch is the only get_evaluations call. A second one would mean the stream
        // gave up and the polling fallback fetched instead.
        XCTAssertEqual(proxy.count(of: ApiPaths.getEvaluations.rawValue), 1)

        // Exactly one stream request, and it has not failed. A stream that opened and then
        // broke would show up here as a retry or an error.
        let streamRequests = proxy.records.filter { $0.path.hasSuffix(Constant.Streaming.STREAM_EVALUATIONS_PATH) }
        XCTAssertEqual(streamRequests.count, 1, "expected one stream request; requests: \(proxy.records)")
        XCTAssertNil(streamRequests.first?.error)
    }

    @MainActor
    func testEvaluationsArriveOverTheStreamWhenTheInitFetchTimesOut() async throws {
        do {
            try await BKTClient.initialize(config: config(), user: user(), timeoutMillis: 1)
            XCTFail("initialize should time out with a 1ms limit")
        } catch let error as BKTError {
            guard case .timeout = error else {
                return XCTFail("expected a timeout, got \(error)")
            }
        }
        // The stream still opens after a failed init fetch, and its snapshot fills the cache.
        let client = try BKTClient.shared

        await assertEventually(timeout: E2EStreamingTimeout.value, "value-1 did not arrive; requests: \(proxy.records)") {
            client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: "") == "value-1"
        }

        // The timed-out init fetch is never retried, and within 1ms it may not even reach the
        // proxy, so it counts 0 or 1. A second call would mean the polling fallback filled the
        // cache instead of the stream.
        XCTAssertLessThanOrEqual(proxy.count(of: ApiPaths.getEvaluations.rawValue), 1)

        // The count above also passes when the stream gave up and the fallback fetched once.
        // Require a clean stream reply, and no REST fetch after the first stream request.
        XCTAssertGreaterThanOrEqual(streamOpenCount, 1, "the stream never opened cleanly; requests: \(proxy.records)")
        guard let firstStream = proxy.records.firstIndex(where: { $0.path.hasSuffix(Constant.Streaming.STREAM_EVALUATIONS_PATH) }) else {
            return XCTFail("no stream request reached the proxy; requests: \(proxy.records)")
        }
        let fetchesAfterStream = proxy.records[firstStream...].filter { $0.path.hasSuffix(ApiPaths.getEvaluations.rawValue) }
        XCTAssertTrue(fetchesAfterStream.isEmpty, "a REST fetch came after the stream request; requests: \(proxy.records)")
    }

    @MainActor
    func testReconnectAfterUpdateUserAttributesReEvaluatesOverTheStream() async throws {
        // feature-ios-e2e-string has a targeting rule on the E2E backend: app_version "0.0.1"
        // resolves to "value-2" with reason RULE instead of the default "value-1".
        // E2EEvaluationTests.testEvaluationUpdateFlow checks the same rule through a REST
        // fetch; this test goes through the stream reconnect that updateUserAttributes starts.
        try await BKTClient.initialize(config: config(), user: user())
        let client = try BKTClient.shared
        await assertEventually(timeout: E2EStreamingTimeout.streamOpen, "the stream did not open; requests: \(proxy.records)") {
            self.streamOpenCount >= 1
        }
        XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")

        let listener = RecordingEvaluationListener {
            client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: "")
        }
        let listenerKey = client.addEvaluationUpdateListener(listener: listener)
        defer { client.removeEvaluationUpdateListener(key: listenerKey) }

        client.updateUserAttributes(attributes: ["app_version": "0.0.1"])

        await assertEventually(timeout: E2EStreamingTimeout.value, "value-2 did not arrive; requests: \(proxy.records)") {
            client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: "") == "value-2"
        }
        // The listener must see value-2 itself. A call for any other update, for example another
        // run changing the shared flag, does not count. The listener runs on the main thread a
        // moment after the value is stored, so wait for it.
        await assertEventually(timeout: E2EStreamingTimeout.value, "the listener never saw value-2; observed: \(listener.observed)") {
            listener.observed.contains("value-2")
        }
        XCTAssertEqual(client.stringVariationDetails(featureId: FEATURE_ID_STRING, defaultValue: "").reason, .rule)

        // The init fetch is the only get_evaluations call. A second one would mean the new
        // attributes were evaluated by a REST fetch instead of the stream reconnect.
        XCTAssertEqual(proxy.count(of: ApiPaths.getEvaluations.rawValue), 1)
        XCTAssertGreaterThanOrEqual(
            proxy.count(of: Constant.Streaming.STREAM_EVALUATIONS_PATH), 2,
            "expected a new stream request after the attribute update"
        )
    }

    @MainActor
    func testServerPushedPatchReachesTheOpenStream() async throws {
        // Fails here, naming the variable, when the write key is missing.
        _ = try E2EFeatureFlagApi.publicApiKey()

        try await BKTClient.initialize(config: config(), user: user())
        let client = try BKTClient.shared

        // Both are sent back with the new value: the server replaces the whole variation.
        let details = client.stringVariationDetails(featureId: FEATURE_ID_STREAMING, defaultValue: "")
        guard !details.variationId.isEmpty else {
            return XCTFail("\(FEATURE_ID_STREAMING) has no evaluation for tag \(FEATURE_TAG); create it in the console")
        }

        let value = E2EFeatureFlagApi.newStreamingTestValue()
        let listener = RecordingEvaluationListener {
            client.stringVariation(featureId: FEATURE_ID_STREAMING, defaultValue: "")
        }
        let listenerKey = client.addEvaluationUpdateListener(listener: listener)
        defer { client.removeEvaluationUpdateListener(key: listenerKey) }

        // Without this, a fast PATCH can land before the stream is open, and the push goes to
        // nobody.
        await assertEventually(timeout: E2EStreamingTimeout.streamOpen, "the stream did not open; requests: \(proxy.records)") {
            self.streamOpenCount >= 1
        }

        try await E2EFeatureFlagApi.setVariationValue(
            featureId: FEATURE_ID_STREAMING,
            variationId: details.variationId,
            variationName: details.variationName,
            value: value
        )

        // Every observed value is checked, not only the latest: an overlapping run can
        // overwrite the flag right after our write.
        await assertEventually(timeout: E2EStreamingTimeout.value, "\(value) never reached the app; observed: \(listener.observed)") {
            listener.observed.contains(value)
        }

        // The init fetch is the only get_evaluations call. A second one would mean the value
        // came from a REST fetch instead of the stream.
        XCTAssertEqual(proxy.count(of: ApiPaths.getEvaluations.rawValue), 1)
    }

    private func config() throws -> BKTConfig {
        try BKTConfig.e2e(enableStreaming: true, apiEndpoint: proxy.url.absoluteString)
    }

    private func user() throws -> BKTUser {
        try BKTUser.Builder().with(id: USER_ID).build()
    }

    /// Stream requests the backend answered with 200 that have not failed since. A stream that
    /// replied 200 and then broke does not count as open.
    private var streamOpenCount: Int {
        proxy.records.filter {
            $0.path.hasSuffix(Constant.Streaming.STREAM_EVALUATIONS_PATH) && $0.status == 200 && $0.error == nil
        }.count
    }
}
