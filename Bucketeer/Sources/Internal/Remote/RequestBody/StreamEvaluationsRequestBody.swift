import Foundation

/// Body sent to `POST /v1/gateway/stream_evaluations` to open (or reconnect) the SSE stream.
///
/// Unlike `GetEvaluationsRequestBody` (the polling path), there is no `userEvaluationCondition`:
/// the stream sends `evaluatedAt` directly, and a user attribute change is carried by
/// reconnecting with a fresh `user.data` rather than by a flag.
struct StreamEvaluationsRequestBody: Codable {
    let tag: String
    let user: User
    let sourceId: SourceID
    let sdkVersion: String
    /// Last known id, "" before anything is cached. Lets the server reply with a diff
    /// instead of a full snapshot.
    let userEvaluationsId: String
    /// Last known evaluatedAt, "0" before anything is cached. A string (not a number) to
    /// match how it round-trips through `UserEvaluations.createdAt` and how the server's
    /// protojson encoding accepts int64 fields.
    let evaluatedAt: String
}
