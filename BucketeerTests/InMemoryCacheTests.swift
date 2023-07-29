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
}
