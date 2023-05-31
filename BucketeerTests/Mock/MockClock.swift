import Foundation
@testable import Bucketeer

final class MockClock: Clock {
    let timestamp: Int64

    init(timestamp: Int64) {
        self.timestamp = timestamp
    }

    var currentTimeMillis: Int64 {
        return timestamp * 1000
    }

    var currentTimeSeconds: Int64 {
        return timestamp
    }
}
