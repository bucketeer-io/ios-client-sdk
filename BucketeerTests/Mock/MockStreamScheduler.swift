import Foundation
@testable import Bucketeer

/// A fake clock for the stream's timers, the iOS stand-in for JS `vi.useFakeTimers()`.
/// Nothing runs until the test calls `advance(byMillis:)`.
final class MockStreamScheduler: StreamScheduler {
    private struct Item {
        let due: Int64
        let order: Int
        let work: DispatchWorkItem
    }

    private(set) var nowMillis: Int64 = 0
    private var items: [Item] = []
    private var nextOrder = 0

    /// Scheduled work that is not cancelled and has not run yet.
    var pendingCount: Int {
        return liveItems().count
    }

    func schedule(afterMillis delay: Int64, _ work: DispatchWorkItem) {
        items.append(Item(due: nowMillis + delay, order: nextOrder, work: work))
        nextOrder += 1
    }

    /// Same meaning as JS `vi.advanceTimersByTime`: runs every uncancelled item that is due at
    /// or before the target time, earliest first (ties in scheduling order), with `nowMillis`
    /// set to each item's due time while it runs. Work scheduled during the advance also runs
    /// if it falls inside the window. Ends with `nowMillis` at the target.
    func advance(byMillis millis: Int64) {
        let target = nowMillis + millis
        while let next = liveItems()
            .filter({ $0.due <= target })
            .min(by: { ($0.due, $0.order) < ($1.due, $1.order) }) {
            items.removeAll { $0.order == next.order }
            nowMillis = next.due
            next.work.perform()
        }
        nowMillis = target
    }

    // `perform()` already skips a cancelled item. Filtering here keeps `pendingCount` honest.
    private func liveItems() -> [Item] {
        return items.filter { !$0.work.isCancelled }
    }
}
