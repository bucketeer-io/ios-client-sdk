import Foundation
import XCTest
@testable import Bucketeer

/// The flag the streaming patch test writes to. Each run writes a fresh value, and no test
/// reads it back as a baseline, so it is never restored.
let FEATURE_ID_STREAMING = "feature-ios-e2e-sse-string"

/// Timeouts for the streaming E2E waits. All stay under 60s: with streaming off, the E2E config
/// polls every 60s, so a longer wait could pass through a poll and hide a broken stream.
enum E2EStreamingTimeout {
    /// The stream's reply, as seen by the proxy server.
    static let streamOpen: TimeInterval = 20
    /// A value or a listener call, as seen by the app.
    static let value: TimeInterval = 20
    /// The test's own PATCH to the backend.
    static let patchRequest: TimeInterval = 10
}

/// Checks `condition` every 100ms until it holds or `timeout` passes, then fails the test with
/// `message`. Runs on the main actor, where evaluation listeners are called.
@available(iOS 13, *)
@MainActor
@discardableResult
func assertEventually(
    timeout: TimeInterval,
    _ message: @autoclosure () -> String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    if condition() { return true }
    XCTFail(message(), file: file, line: line)
    return false
}

/// Records every listener call and the value read at that moment, instead of only the latest
/// value: an overlapping CI run can overwrite the patch test's flag right after our write.
/// Listeners are called on the main thread, and the tests read this on the main actor.
final class RecordingEvaluationListener: EvaluationUpdateListener {
    private let read: () -> String
    private(set) var observed: [String] = []

    init(read: @escaping () -> String) {
        self.read = read
    }

    func onUpdate() {
        observed.append(read())
    }
}

/// Writes flag values on the backend for the streaming patch test. Calls go straight to
/// E2E_API_ENDPOINT, never through the proxy server, which only carries the SDK's traffic.
enum E2EFeatureFlagApi {
    struct RequestError: LocalizedError {
        let errorDescription: String?
    }

    /// The write key. Fails with a message naming the variable, instead of a 401 from the
    /// server that doesn't say what is missing.
    static func publicApiKey() throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["E2E_PUBLIC_API_KEY"], !apiKey.isEmpty else {
            throw RequestError(errorDescription: "E2E_PUBLIC_API_KEY is not set (needed by the streaming patch tests)")
        }
        return apiKey
    }

    /// A value no other run writes, so two overlapping runs never wait for the same value.
    static func newStreamingTestValue() -> String {
        let millis = Int64(Date().timeIntervalSince1970 * 1_000)
        return "ios-sse-e2e-\(millis)-\(UUID().uuidString.prefix(4).lowercased())"
    }

    /// Replaces the value of one variation. The server replaces the whole variation, so its
    /// current name must be sent along with the new value.
    static func setVariationValue(
        featureId: String,
        variationId: String,
        variationName: String,
        value: String
    ) async throws {
        let apiKey = try publicApiKey()
        let endpoint = ProcessInfo.processInfo.environment["E2E_API_ENDPOINT"]!

        var request = URLRequest(url: URL(string: endpoint)!.appendingPathComponent("v1/feature"))
        request.httpMethod = "PATCH"
        request.timeoutInterval = E2EStreamingTimeout.patchRequest
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "id": featureId,
            "comment": "ios e2e streaming test",
            "variationChanges": [
                [
                    "changeType": "UPDATE",
                    "variation": ["id": variationId, "name": variationName, "value": value]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let reason = String(decoding: data, as: UTF8.self)
            throw RequestError(errorDescription: "failed to update \(featureId): HTTP \(status) \(reason)")
        }
    }
}
