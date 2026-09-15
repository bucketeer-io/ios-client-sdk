import XCTest
@testable import Bucketeer

final class StreamBackoffTests: XCTestCase {

    // MARK: - nextDelayMillis

    func testStartsAtInitialDelayAndDoublesUntilMaxThenCaps() {
        var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000, random: { 0 })

        XCTAssertEqual(backoff.nextDelayMillis(), 1_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 2_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 4_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 8_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 16_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 30_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 30_000)
    }

    func testClampsInitialDelayGreaterThanMaxOnFirstCall() {
        var backoff = StreamBackoff(initialDelayMillis: 40_000, maxDelayMillis: 30_000, random: { 0 })

        XCTAssertEqual(backoff.nextDelayMillis(), 30_000)
    }

    func testSubtractsUpToJitterRatioOfBaseDelay() {
        var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000, random: { 1 })

        // base 1_000, JITTER_RATIO 0.5, random 1 -> subtract the full 50%
        XCTAssertEqual(backoff.nextDelayMillis(), 500)
        XCTAssertEqual(backoff.nextDelayMillis(), 1_000)
    }

    // MARK: - reset

    func testResetSetsAttemptBackToZero() {
        var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000, random: { 0 })

        XCTAssertEqual(backoff.nextDelayMillis(), 1_000)
        XCTAssertEqual(backoff.nextDelayMillis(), 2_000)

        backoff.reset()

        XCTAssertEqual(backoff.nextDelayMillis(), 1_000)
    }

    // MARK: - iOS-specific: math safety (Swift crashes on overflow/NaN where JS would not)

    /// A very long streak of failures must never crash: neither an integer overflow
    /// from naive doubling, nor a `Double` "not a number" result from an uncapped exponent.
    func testManyAttemptsNeverCrashAndStayCappedAtMax() {
        var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000, random: { 0 })

        var lastDelay: Int64 = 0
        for _ in 0..<10_000 {
            lastDelay = backoff.nextDelayMillis()
        }
        XCTAssertEqual(lastDelay, 30_000)
    }

    /// initialDelayMillis: 0 must not produce `0 * infinity = NaN` once the exponent grows large,
    /// which would crash on the `Int64(NaN)` conversion.
    func testZeroInitialDelayNeverCrashesAndProducesNoDelay() {
        var backoff = StreamBackoff(initialDelayMillis: 0, maxDelayMillis: 30_000, random: { 0 })

        XCTAssertEqual(backoff.nextDelayMillis(), 1)
        XCTAssertEqual(backoff.nextDelayMillis(), 2)
        XCTAssertEqual(backoff.nextDelayMillis(), 4)

        for _ in 0..<10_000 {
            _ = backoff.nextDelayMillis()
        }
        // no crash
    }

    /// Non-positive inputs are raised to 1 so there is never a zero-delay reconnect loop.
    func testNonPositiveDelaysAreRaisedToOne() {
        var backoff = StreamBackoff(initialDelayMillis: -5, maxDelayMillis: 0, random: { 0 })

        for _ in 0..<5 {
            XCTAssertEqual(backoff.nextDelayMillis(), 1)
        }
    }

    /// With the real random generator, every delay stays within [base/2, base] of the expected base.
    func testRealRandomStaysWithinExpectedBounds() {
        for _ in 0..<1_000 {
            var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000)
            let delay = backoff.nextDelayMillis()
            XCTAssertTrue((500...1_000).contains(delay), "delay was \(delay)")
        }
    }
}
