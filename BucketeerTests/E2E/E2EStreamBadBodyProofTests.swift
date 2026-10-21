import Foundation
import XCTest
@testable import Bucketeer

/// Throwaway checks for how the stream endpoint answers a body it cannot decode. Not meant
/// to be merged.
///
/// The bodies are the real request bodies the SDK builds (`StreamEvaluationsRequestBody`,
/// `GetEvaluationsRequestBody`). The one change is a user attribute sent as a number instead
/// of a string. The iOS SDK cannot send that ([String: String]), but the JavaScript SDK does
/// not check attribute types at runtime, so a plain JavaScript app can.
@available(iOS 13, *)
final class E2EStreamBadBodyProofTests: XCTestCase {

    /// Expected to fail today with 500: the stream treats the undecodable body as a server fault.
    func testStreamNumberAttributeIs400() async throws {
        let body = try realBody(streamBody(), numberAttribute: true)
        try await assertStatus(path: Constant.Streaming.STREAM_EVALUATIONS_PATH, body: body, apiKey: validApiKey(), expected: 400)
    }

    /// Control: polling already answers the same attribute with 400.
    func testPollNumberAttributeIs400() async throws {
        let body = try realBody(pollBody(), numberAttribute: true)
        try await assertStatus(path: ApiPaths.getEvaluations.rawValue, body: body, apiKey: validApiKey(), expected: 400)
    }

    /// Control: the same stream body with a string attribute decodes fine. A bad API key makes
    /// it stop at 401, so no stream is opened.
    func testStreamStringAttributeWithBadApiKeyIs401() async throws {
        let body = try realBody(streamBody(), numberAttribute: false)
        try await assertStatus(path: Constant.Streaming.STREAM_EVALUATIONS_PATH, body: body, apiKey: "invalid-api-key", expected: 401)
    }

    private func validApiKey() -> String {
        ProcessInfo.processInfo.environment["E2E_API_KEY"]!
    }

    private func user() -> User {
        User(id: USER_ID, data: ["app_version": "0.0.1"])
    }

    private func streamBody() throws -> Data {
        try JSONEncoder().encode(StreamEvaluationsRequestBody(
            tag: FEATURE_TAG,
            user: user(),
            sourceId: .ios,
            sdkVersion: Version.current,
            userEvaluationsId: "",
            evaluatedAt: "0"
        ))
    }

    private func pollBody() throws -> Data {
        try JSONEncoder().encode(GetEvaluationsRequestBody(
            tag: FEATURE_TAG,
            user: user(),
            userEvaluationsId: "",
            sourceId: .ios,
            userEvaluationCondition: UserEvaluationCondition(evaluatedAt: "0", userAttributesUpdated: false),
            sdkVersion: Version.current
        ))
    }

    /// Adds `"age": 30` (a number) or `"age": "30"` (a string) to `user.data`, the only change
    /// from the body the SDK sends.
    private func realBody(_ encoded: Data, numberAttribute: Bool) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var user = try XCTUnwrap(json["user"] as? [String: Any])
        var data = user["data"] as? [String: Any] ?? [:]
        data["age"] = numberAttribute ? 30 : "30"
        user["data"] = data
        json["user"] = user
        return try JSONSerialization.data(withJSONObject: json)
    }

    /// Sends one request and checks only the status. Every case here gets an error reply right
    /// away, so no stream is opened.
    private func assertStatus(
        path: String,
        body: Data,
        apiKey: String,
        expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let endpoint = ProcessInfo.processInfo.environment["E2E_API_ENDPOINT"]!
        var request = URLRequest(url: URL(string: endpoint)!.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let sent = String(decoding: body, as: UTF8.self)
        let reply = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(status, expected, "\(path) with \(sent): HTTP \(status) \(reply)", file: file, line: line)
    }
}
