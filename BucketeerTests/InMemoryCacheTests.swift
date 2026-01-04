import XCTest
@testable import Bucketeer

final class InMemoryCacheTests: XCTestCase {

    func testGetSet() throws {
        let memCache = InMemoryCache<String>()
        // Prefill state
        memCache.set(key: "key", value: "value")
        memCache.set(key: "key", value: "value2")
        memCache.set(key: "key1", value: "value1")

        XCTAssertEqual(memCache.get(key: "key"), "value2")
        XCTAssertEqual(memCache.get(key: "key1"), "value1")
    }

    func testConcurrentAccess() {
        let cache = InMemoryCache<Int>()
        let queue = DispatchQueue(label: "test.concurrent.queue", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 1000

        // 1. Perform many concurrent writes
        for i in 0..<iterations {
            group.enter()
            queue.async {
                cache.set(key: "key-\(i)", value: i)
                group.leave()
            }
        }

        // 2. Perform many concurrent reads and writes mixed together
        for i in 0..<iterations {
            group.enter()
            queue.async {
                // Randomly choose to read or write to stress test the barrier
                if Bool.random() {
                    cache.set(key: "shared-key", value: i)
                } else {
                    _ = cache.get(key: "shared-key")
                }
                group.leave()
            }
        }

        // 3. Wait for all operations to complete
        let result = group.wait(timeout: .now() + 5.0)

        XCTAssertEqual(result, .success, "Concurrent operations timed out")

        // 4. Verify data integrity (basic check)
        // We know "key-0" through "key-999" should exist
        for i in 0..<iterations {
            XCTAssertEqual(cache.get(key: "key-\(i)"), i)
        }
    }

    func testConcurrentAccessThreadSafety() {
        let cache = InMemoryCache<Evaluation>()
        // Use a concurrent queue to simulate multiple threads hitting the cache
        let queue = DispatchQueue(label: "io.bucketeer.tests.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 2000

        // 1. Populate initial data (Static keys that shouldn't change)
        for i in 0..<100 {
            cache.set(key: "static-key-\(i)", value: .mock1)
        }

        // 2. Stress Test: Simultaneous Reads and Writes
        for i in 0..<iterations {
            group.enter()
            queue.async {
                // Mix Reads and Writes deterministically (50/50 split)
                if i % 2 == 0 {
                    // WRITE: Should trigger the barrier
                    // Toggle between two values to force memory updates
                    let value: Evaluation = (i % 4 == 0) ? .mock1 : .mock1Updated
                    cache.set(key: "hot-key", value: value)
                } else {
                    // READ: Should run in parallel (unless blocked by barrier)

                    // 1. Verify static data integrity (should never be corrupted by the write barrier)
                    let staticVal = cache.get(key: "static-key-\(i % 100)")
                    XCTAssertEqual(staticVal?.id, Evaluation.mock1.id, "Static data corrupted during concurrent write")

                    // 2. Read the hot key (value might change, but shouldn't crash)
                    _ = cache.get(key: "hot-key")
                }
                group.leave()
            }
        }

        // 3. Wait for completion
        let result = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(result, .success, "Test timed out. Possible deadlock in barrier logic.")

        // 4. Final State Verification
        // The 'hot-key' must be in a valid state (either mock1 or mock1Updated), not corrupted/nil.
        let finalValue = cache.get(key: "hot-key")
        XCTAssertNotNil(finalValue)
        XCTAssertTrue(finalValue?.id == Evaluation.mock1.id || finalValue?.id == Evaluation.mock1Updated.id)
    }
}
