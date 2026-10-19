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

    /// A max delay of `Int64.max` must not crash. `Double(Int64.max)` rounds up to 2^63, which no
    /// longer fits in an `Int64`, so the delay must never be allowed to grow that far.
    func testHugeMaxDelayNeverCrashesAndKeepsGrowing() {
        var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: Int64.max, random: { 0 })

        var previousDelay: Int64 = 0
        for _ in 0..<200 {
            let delay = backoff.nextDelayMillis()
            XCTAssertGreaterThanOrEqual(delay, previousDelay)
            previousDelay = delay
        }
        XCTAssertGreaterThan(previousDelay, 30_000)
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

    // MARK: - jitter with random values other than 0
    //
    // Pinning random to 0 switches the jitter off, so the tests above cannot notice a jitter
    // bug. The tests below use other random values, in two styles:
    //  - pinned values with hand-computed, exact expected delays (deterministic)
    //  - the real generator with range checks only (never an exact number, so never flaky)

    /// The jitter formula in isolation: same base delay, different random values.
    /// The expected delays are worked out by hand (base 1_000, JITTER_RATIO 0.5), not with the
    /// production formula. The random values are binary-exact fractions, so there is no rounding noise.
    func testJitterScalesWithRandomValueAtAFixedBase() {
        let expectedDelayByRandom: [(random: Double, delay: Int64)] = [
            (0.0, 1_000),
            (0.25, 875),
            (0.5, 750),
            (0.75, 625)
        ]

        for (random, expectedDelay) in expectedDelayByRandom {
            var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000, random: { random })

            XCTAssertEqual(backoff.nextDelayMillis(), expectedDelay, "random \(random)")
        }
    }

    /// Random returns a different in-between value on every call. This also proves each jitter is
    /// applied to a fresh doubled base and is not carried into the next attempt's base: if the next
    /// base were built from the previous jittered delay, the second value would not be 1_500.
    func testDifferentRandomValuesEachReduceTheirOwnBaseDelay() {
        // Binary-exact fractions, so the expected numbers below have no rounding noise.
        var randomValues: [Double] = [0.25, 0.5, 0.75, 0.125]
        var backoff = StreamBackoff(
            initialDelayMillis: 1_000,
            maxDelayMillis: 30_000,
            random: { randomValues.removeFirst() }
        )

        // base 1_000 - 0.25 * 0.5 * 1_000 = 875
        XCTAssertEqual(backoff.nextDelayMillis(), 875)
        // base 2_000 - 0.5 * 0.5 * 2_000 = 1_500
        XCTAssertEqual(backoff.nextDelayMillis(), 1_500)
        // base 4_000 - 0.75 * 0.5 * 4_000 = 2_500
        XCTAssertEqual(backoff.nextDelayMillis(), 2_500)
        // base 8_000 - 0.125 * 0.5 * 8_000 = 7_500
        XCTAssertEqual(backoff.nextDelayMillis(), 7_500)
    }

    /// Once doubling reaches the cap, jitter is taken from the capped base (30_000), not from the
    /// doubled number before the cap (32_000).
    func testJitterIsTakenFromTheCappedDelayAfterDoubling() {
        var randomValues: [Double] = [0, 0, 0, 0, 0, 0.5]
        var backoff = StreamBackoff(
            initialDelayMillis: 1_000,
            maxDelayMillis: 30_000,
            random: { randomValues.removeFirst() }
        )

        // 1_000, 2_000, 4_000, 8_000, 16_000 with no jitter, so the next base is capped 32_000 -> 30_000
        for _ in 0..<5 {
            _ = backoff.nextDelayMillis()
        }

        // base 30_000 - 0.5 * 0.5 * 30_000 = 22_500
        XCTAssertEqual(backoff.nextDelayMillis(), 22_500)
    }

    /// An initial delay above the max is clamped first, and jitter is taken from the clamped
    /// base (30_000), not from the initial delay (40_000).
    func testJitterIsTakenFromTheClampedDelayWhenInitialExceedsMax() {
        var backoff = StreamBackoff(initialDelayMillis: 40_000, maxDelayMillis: 30_000, random: { 0.5 })

        // base 30_000 - 0.5 * 0.5 * 30_000 = 22_500
        XCTAssertEqual(backoff.nextDelayMillis(), 22_500)
    }

    /// `Double.random(in: 0..<1)` never returns exactly 1, so the largest value it can return is
    /// just below 1. Here the jitter works out to 499.99999999999994, and it is dropped to a whole
    /// millisecond (499) before it is subtracted, so the delay is 501. Subtracting first and
    /// dropping the fraction afterwards would give 500, and this test would fail.
    func testLargestPossibleRandomValueGivesExactly501() {
        var backoff = StreamBackoff(
            initialDelayMillis: 1_000,
            maxDelayMillis: 30_000,
            random: { 1.0.nextDown }
        )

        XCTAssertEqual(backoff.nextDelayMillis(), 501)
    }

    /// Walks the whole doubling sequence, including the cap, with the real random generator.
    /// Every attempt's delay must stay within [base/2, base] for that attempt's own base.
    func testRealRandomStaysWithinBoundsOnEveryAttempt() {
        for _ in 0..<1_000 {
            var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000)

            for attempt in 0..<12 {
                let base = min(Int64(1_000) << Int64(attempt), 30_000)
                let delay = backoff.nextDelayMillis()
                XCTAssertTrue(
                    (base / 2...base).contains(delay),
                    "attempt \(attempt): delay was \(delay), expected within \(base / 2)...\(base)"
                )
            }
        }
    }

    /// Guards against jitter being switched off or squeezed into a narrow range. The first delay
    /// can be anything from 501 to 1_000, so over many draws the smallest must land near the bottom
    /// and the largest near the top. The chance of a false failure is below 1 in 10^15.
    func testRealRandomCoversTheWholeJitterRange() {
        var smallestDelay = Int64.max
        var largestDelay = Int64.min

        for _ in 0..<2_000 {
            var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000)
            let delay = backoff.nextDelayMillis()
            smallestDelay = min(smallestDelay, delay)
            largestDelay = max(largestDelay, delay)
        }

        XCTAssertLessThanOrEqual(smallestDelay, 510, "smallest delay was \(smallestDelay)")
        XCTAssertGreaterThanOrEqual(largestDelay, 990, "largest delay was \(largestDelay)")
    }

    /// With very small delays, the jitter is dropped to a whole millisecond, so it must never push
    /// the delay to 0 (a tight reconnect loop), whatever random returns.
    func testRealRandomNeverProducesZeroDelayForTinyDelays() {
        for _ in 0..<1_000 {
            var backoff = StreamBackoff(initialDelayMillis: 1, maxDelayMillis: 3)

            for _ in 0..<10 {
                let delay = backoff.nextDelayMillis()
                XCTAssertGreaterThanOrEqual(delay, 1, "delay was \(delay)")
            }
        }
    }

    /// While the doubling is still below the cap, every retry must wait longer than the one before,
    /// even with randomness. The next delay is at least base + 1 and the previous one is at most
    /// base, because random is always below 1. This stops holding if JITTER_RATIO goes above 0.5.
    func testRealRandomDelayAlwaysGrowsWhileBelowTheCap() {
        for _ in 0..<1_000 {
            var backoff = StreamBackoff(initialDelayMillis: 1_000, maxDelayMillis: 30_000)
            var previousDelay: Int64 = 0

            // bases 1_000, 2_000, 4_000, 8_000, 16_000: all below the 30_000 cap
            for attempt in 0..<5 {
                let delay = backoff.nextDelayMillis()
                XCTAssertGreaterThan(delay, previousDelay, "attempt \(attempt): \(delay) after \(previousDelay)")
                previousDelay = delay
            }
        }
    }
}
