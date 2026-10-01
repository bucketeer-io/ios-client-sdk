import Foundation

/// "Now" and "run this later" for the stream's timers, so tests can control time
/// (the iOS replacement for JS `setTimeout` / `Date.now`, and for `vi.useFakeTimers` in tests).
///
/// Not thread-safe: use it from the queue it runs work on, the serial SDK queue in production.
protocol StreamScheduler: AnyObject {
    /// Milliseconds on a clock that only moves forward. Only the difference between two
    /// readings means anything.
    var nowMillis: Int64 { get }
    /// Runs `work` after `delay` ms unless it is cancelled first (`work.cancel()`).
    func schedule(afterMillis delay: Int64, _ work: DispatchWorkItem)
}

/// Runs the stream's timers on the SDK queue with `asyncAfter`.
final class DispatchStreamScheduler: StreamScheduler {
    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    /// Time since boot. It only moves forward, doesn't jump when the user changes the device
    /// time, and is the clock `asyncAfter` uses.
    var nowMillis: Int64 {
        return Int64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
    }

    func schedule(afterMillis delay: Int64, _ work: DispatchWorkItem) {
        queue.asyncAfter(deadline: .now() + .milliseconds(Int(delay)), execute: work)
    }
}
