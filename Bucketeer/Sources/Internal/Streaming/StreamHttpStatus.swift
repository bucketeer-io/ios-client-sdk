import Foundation

/// Retry classification for SSE stream HTTP statuses.
///
/// There are THREE categories, but only two are named as sets below. The third
/// is the default, defined by absence from both (easy to miss when adding a
/// status, so read this first).
///
/// The single consumer is `StreamConnection`'s error handling, which branches in this order:
///
///   1. RETRY FAST (`isRecoverable` returns true)
///      Backoff retries (1s to 30s, jittered).
///      Use for failures that fix themselves in SECONDS (a 503 from the
///      server's SSE connection-limit guard, a transient 5xx, a 408/429/499).
///
///   2. RETRY SLOW (in NEITHER set: the default for any unlisted 4xx, e.g. 400, 413, 422)
///      Give up on this attempt immediately, fall back to polling, and retry
///      streaming after a longer recovery interval.
///      Use for failures that fix themselves in MINUTES, or only when the app
///      acts (e.g. the request body changes on the next attempt).
///
///   3. NEVER RETRY (`isTerminal` returns true)
///      Permanent for the life of this client (bad API key, streaming
///      unsupported at this URL). Only destroy + re-initialize brings
///      streaming back.
///
/// To pick a category, ask what would have to CHANGE for a retry to succeed, and
/// how fast that thing changes.
///
/// WHY 400/413/422 ARE NEITHER: they are decided by the request BODY (user
/// attributes, cache state), which a same-request fast retry cannot change, so
/// category 1 would just resend the same failing request. They are not
/// terminal either, because unlike a fixed API key, method or URL, the body
/// CAN legitimately differ on a later attempt (the app calls
/// updateUserAttributes(), or the cache refreshes). The SDK cannot tell
/// whether the backend objected to a fixed part of the request or a mutable
/// one, so category 2 is the conservative middle ground for that ambiguity.
enum StreamHttpStatus {

    // 499 is a deployment-related "client closed request" status that the polling
    // path (ApiClientImpl) already retries for the same reason: a backend rollout
    // that polling survives must not kill the stream instead.
    private static let recoverable4xx: Set<Int> = [
        408,
        429,
        ApiClientImpl.CLIENT_CLOSED_THE_CONNECTION_CODE // 499
    ]

    // Decided entirely by parts of the REQUEST that cannot change while this client
    // runs (the API key, the URL, the method, or a fixed header) rather than by
    // transient server state.
    private static let terminalStatuses: Set<Int> = [
        401, // Unauthorized: bad API key
        403, // Forbidden: bad API key
        404, // Not Found: same URL, will not appear on its own
        405, // Method Not Allowed: same method every request
        406, // Not Acceptable: same fixed Accept header every request
        410, // Gone: permanent by definition
        414, // URI Too Long: malformed URL, won't self-resolve
        415, // Unsupported Media Type: same fixed Content-Type every request
        431, // Request Header Fields Too Large: same headers every request
        451  // Unavailable For Legal Reasons: permanent
    ]

    /// true: retry quickly with backoff. `nil` means no HTTP response reached us (network error),
    /// which is treated the same as a transient failure.
    static func isRecoverable(_ status: Int?) -> Bool {
        guard let status = status else { return true }
        guard 400..<500 ~= status else { return true } // 5xx (incl. 503 connection limit) and anything unusual
        return recoverable4xx.contains(status)
    }

    /// true: retrying the same request can never succeed; stop streaming for this client's lifetime.
    static func isTerminal(_ status: Int?) -> Bool {
        guard let status = status else { return false }
        return terminalStatuses.contains(status)
    }
}
