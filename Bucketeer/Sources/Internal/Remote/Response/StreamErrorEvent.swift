import Foundation

/// Payload of the SSE `error` event, sent by the server immediately before it closes the
/// stream. Used only for logging, so every field is optional: a decode failure here must
/// never prevent the caller from handling the underlying connection error.
///
/// There is no separate type for the `put`/`patch` payload: it has the exact same wire
/// shape as the polling path's response (`{"userEvaluationsId": ..., "evaluations": {...}}`,
/// both wrapping the same backend `feature.UserEvaluations` message), so it is decoded
/// directly as `GetEvaluationsResponse`. See `StreamEvaluationsModelTests` for the test that
/// locks in that shared-shape assumption.
struct StreamErrorEvent: Decodable {
    let code: String?
    let message: String?
}
