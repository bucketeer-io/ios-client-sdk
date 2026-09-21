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
///
/// That decode is intentionally strict, with no defaults for missing fields, and a lenient
/// decoder for omitted zero-valued fields is deliberately not added. The backend marshals every
/// stream event with `protojson.MarshalOptions{EmitUnpopulated: true}`, so zero values
/// (`forceUpdate: false`, `[]`, `""`) are always present in the JSON and never omitted:
/// - marshal options: https://github.com/bucketeer-io/bucketeer/blob/900853e2cb1fbdfa026974d89fc3cbdcb21789d0/pkg/api/stream/evaluations.go#L55
/// - applied to every `put`/`patch`/`error` event: https://github.com/bucketeer-io/bucketeer/blob/900853e2cb1fbdfa026974d89fc3cbdcb21789d0/pkg/api/stream/evaluations.go#L254
///
/// The polling path has decoded this same shape with this same type in production for a long
/// time without needing defaults.
struct StreamErrorEvent: Decodable {
    let code: String?
    let message: String?
}
