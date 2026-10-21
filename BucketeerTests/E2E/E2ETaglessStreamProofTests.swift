import Foundation
import XCTest
@testable import Bucketeer

/// Throwaway check: does the stream open with an empty feature tag? The test expects it to,
/// so a failure shows the gap. `E2EStreamingProxyTests.testStreamOpensAfterInit` is the
/// control: the same flow with the "ios" tag. Not meant to be merged.
@available(iOS 13, *)
final class E2ETaglessStreamProofTests: XCTestCase {
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

    /// Expected to fail today: the stream answers 400 "tag is required" to an empty tag.
    /// The failure message lists each request with its status.
    @MainActor
    func testTaglessStreamOpens() async throws {
        let config = try BKTConfig.e2e(featureTag: "", enableStreaming: true, apiEndpoint: proxy.url.absoluteString)
        try await BKTClient.initialize(config: config, user: user())

        await assertEventually(timeout: E2EStreamingTimeout.streamOpen, "the tagless stream did not open; requests: \(proxy.records)") {
            self.proxy.records.contains {
                $0.path.hasSuffix(Constant.Streaming.STREAM_EVALUATIONS_PATH) && $0.status == 200
            }
        }
    }

    private func user() throws -> BKTUser {
        try BKTUser.Builder().with(id: USER_ID).build()
    }
}
