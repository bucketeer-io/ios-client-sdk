import Foundation
import XCTest
@testable import Bucketeer

/// Streaming E2E tests with a direct connection to the backend, as close as a real app. This
/// is the only E2E run where the SDK's own stream connection meets the real gateway (TLS,
/// HTTP/2, real chunking and buffering).
///
/// These tests check only what an app can see: values, reasons and listener calls. They
/// cannot tell whether a value came from the stream or from the polling fallback;
/// `E2EStreamingProxyTests` checks that for the same cases. See `BucketeerTests/E2E/README.md`.
@available(iOS 13, *)
final class E2EStreamingDirectTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults.removeAllEvaluationData()
        try? FileManager.default.removeItem(at: .database)
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()

        try BKTClient.destroy()
        UserDefaults.removeAllEvaluationData()
        try? FileManager.default.removeItem(at: .database)
    }

    @MainActor
    func testReconnectAfterUpdateUserAttributesReEvaluatesOverTheStream() async throws {
        // feature-ios-e2e-string has a targeting rule on the E2E backend: app_version "0.0.1"
        // resolves to "value-2" with reason RULE instead of the default "value-1".
        try await BKTClient.initialize(config: config(), user: user())
        let client = try BKTClient.shared
        XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")

        let listener = RecordingEvaluationListener {
            client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: "")
        }
        let listenerKey = client.addEvaluationUpdateListener(listener: listener)
        defer { client.removeEvaluationUpdateListener(key: listenerKey) }

        client.updateUserAttributes(attributes: ["app_version": "0.0.1"])

        await assertEventually(timeout: E2EStreamingTimeout.value, "value-2 did not arrive") {
            client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: "") == "value-2"
        }
        // The listener must see value-2 itself. A call for any other update, for example another
        // run changing the shared flag, does not count. The listener runs on the main thread a
        // moment after the value is stored, so wait for it.
        await assertEventually(timeout: E2EStreamingTimeout.value, "the listener never saw value-2; observed: \(listener.observed)") {
            listener.observed.contains("value-2")
        }
        XCTAssertEqual(client.stringVariationDetails(featureId: FEATURE_ID_STRING, defaultValue: "").reason, .rule)
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

        // No wait for the stream to open: an app cannot see that. If the write lands before
        // the stream opens, the value may never arrive and this test fails on its own message.
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
    }

    private func config() throws -> BKTConfig {
        try BKTConfig.e2e(enableStreaming: true)
    }

    private func user() throws -> BKTUser {
        try BKTUser.Builder().with(id: USER_ID).build()
    }
}
