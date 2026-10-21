import Foundation
import XCTest
@testable import Bucketeer

/// Throwaway check: with an empty feature tag, does polling see a flag change after the first
/// fetch? The test expects it to, so a failure shows the gap. Not meant to be merged.
@available(iOS 13, *)
final class E2ETaglessPollingProofTests: XCTestCase {
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
        proxy?.stop()
        UserDefaults.removeAllEvaluationData()
        try? FileManager.default.removeItem(at: .database)
    }

    /// Expected to fail today: with an empty tag, get_evaluations builds its userEvaluationsId
    /// from no flags, so every later poll answers "no change".
    @MainActor
    func testTaglessPollSeesFlagChange() async throws {
        try await assertPollSeesFlagChange(featureTag: "")
    }

    /// Control: the same flow with the "ios" tag. If this fails too, the cause is not the tag
    /// (for example backend cache lag or another run overwriting the flag).
    @MainActor
    func testTaggedPollSeesFlagChange() async throws {
        try await assertPollSeesFlagChange(featureTag: FEATURE_TAG)
    }

    /// Polling only: init (first fetch), change a flag on the backend, then fetch again until
    /// the new value arrives. A tagless and a tagged run differ only in `featureTag`.
    @MainActor
    private func assertPollSeesFlagChange(featureTag: String) async throws {
        _ = try E2EFeatureFlagApi.publicApiKey()

        let config = try BKTConfig.e2e(featureTag: featureTag, apiEndpoint: proxy.url.absoluteString)
        try await BKTClient.initialize(config: config, user: user())
        let client = try BKTClient.shared

        let details = client.stringVariationDetails(featureId: FEATURE_ID_STREAMING, defaultValue: "")
        guard !details.variationId.isEmpty else {
            return XCTFail("\(FEATURE_ID_STREAMING) has no evaluation for tag \"\(featureTag)\"")
        }
        let idBefore = client.component.evaluationInteractor.cachedEvaluationsState.userEvaluationsId

        let value = E2EFeatureFlagApi.newStreamingTestValue()
        try await E2EFeatureFlagApi.setVariationValue(
            featureId: FEATURE_ID_STREAMING,
            variationId: details.variationId,
            variationName: details.variationName,
            value: value
        )

        // Fetch every 2s: the backend's feature cache can take a few seconds to see the write.
        let deadline = Date().addingTimeInterval(E2EStreamingTimeout.value)
        var seen: [String] = []
        while Date() < deadline {
            try await client.fetchEvaluations(timeoutMillis: nil)
            let current = client.stringVariation(featureId: FEATURE_ID_STREAMING, defaultValue: "")
            seen.append(current)
            if current == value { return }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        let idAfter = client.component.evaluationInteractor.cachedEvaluationsState.userEvaluationsId
        XCTFail(
            "tag \"\(featureTag)\": \(value) never arrived by polling; seen: \(seen); "
                + "userEvaluationsId before: \(idBefore), after: \(idAfter); requests: \(proxy.records)"
        )
    }

    private func user() throws -> BKTUser {
        try BKTUser.Builder().with(id: USER_ID).build()
    }
}
