import Foundation

/// Exponential backoff with jitter for SSE stream reconnect attempts.
///
/// Not thread-safe: intended to be owned and mutated from a single queue,
/// same contract as `Retrier` and `StreamConnection`.
///
/// Unlike `Retrier` (used for the polling API's 499 retries), this has no
/// maximum attempt count, has randomized jitter, and can be reset once a
/// connection proves stable. Those differences are what a reconnect loop
/// that can run for hours needs, so it is a separate, small type rather than
/// a `Retrier` variant.
struct StreamBackoff {
    static let DEFAULT_INITIAL_DELAY_MILLIS: Int64 = 1_000
    static let DEFAULT_MAX_DELAY_MILLIS: Int64 = 30_000
    static let JITTER_RATIO: Double = 0.5

    // 2^30 ms is about 12 days, far above any realistic maxDelayMillis, so capping
    // the exponent here never changes a real (reachable) delay. Belt-and-suspenders
    // against Swift's crash-on-NaN behavior: `init` already floors both delays to at
    // least 1, so `initialDelayMillis * pow(2, attempt)` can only reach `0 * infinity`
    // (`Double.nan`) if that floor is ever removed or bypassed — this cap keeps `base`
    // finite even then, since `Int64(Double.nan)` traps. See
    // testManyAttemptsNeverCrashAndStayCappedAtMax / testZeroInitialDelayNeverCrashesAndProducesNoDelay.
    private static let MAX_EXPONENT = 30

    private let initialDelayMillis: Int64
    private let maxDelayMillis: Int64
    private let random: () -> Double
    private var attempt = 0

    /// - Parameters:
    ///   - initialDelayMillis: Delay for the first call to `nextDelayMillis()`. Values below 1
    ///     are raised to 1 (a 0 delay would mean reconnecting in a tight loop).
    ///   - maxDelayMillis: Upper bound the delay never exceeds. Values below 1 are raised to 1.
    ///   - random: Source of randomness for jitter, `Double.random(in: 0..<1)` by default.
    ///     Injectable so tests can pin it, the same idea as `MockClock`.
    init(
        initialDelayMillis: Int64 = DEFAULT_INITIAL_DELAY_MILLIS,
        maxDelayMillis: Int64 = DEFAULT_MAX_DELAY_MILLIS,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.initialDelayMillis = max(1, initialDelayMillis)
        self.maxDelayMillis = max(1, maxDelayMillis)
        self.random = random
    }

    /// Delay before the next reconnect attempt, in milliseconds. Each call counts as one
    /// more attempt: the base delay doubles (capped at maxDelayMillis) and is then reduced
    /// by a random amount up to JITTER_RATIO of the base, so many clients don't reconnect at
    /// the exact same moment.
    mutating func nextDelayMillis() -> Int64 {
        let exponent = min(attempt, StreamBackoff.MAX_EXPONENT)
        let base = min(Double(initialDelayMillis) * pow(2, Double(exponent)), Double(maxDelayMillis))
        attempt += 1
        let jitter = random() * StreamBackoff.JITTER_RATIO * base
        return Int64(base) - Int64(jitter)
    }

    /// Starts over from the initial delay. Call once a connection has proven stable, so the
    /// next drop backs off from scratch instead of continuing to escalate.
    mutating func reset() {
        attempt = 0
    }
}
