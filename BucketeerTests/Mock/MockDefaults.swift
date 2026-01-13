import Foundation
@testable import Bucketeer

final class MockDefaults: Defaults {
    // Use a concurrent queue so multiple readers can run concurrently.
    // Writes must be exclusive, so use barrier flags to serialize them and ensure visibility.
    private let queue = DispatchQueue(label: "com.bucketeer.mockdefaults.queue", attributes: .concurrent)

    // Underlying storage; only access while synchronized on `queue`.
    private var _dict: [String: Any?] = [:]

    private var dict: [String: Any?] {
        get { queue.sync { _dict } }
        set { queue.sync(flags: .barrier) { _dict = newValue } }
    }

    func bool(forKey defaultName: String) -> Bool {
        return queue.sync { _dict[defaultName] as? Bool ?? false }
    }

    func string(forKey defaultName: String) -> String? {
        return queue.sync { _dict[defaultName] as? String }
    }

    func set(_ value: Any?, forKey defaultName: String) {
        queue.sync(flags: .barrier) { _dict[defaultName] = value }
    }

    func removeObject(forKey defaultName: String) {
        queue.sync(flags: .barrier) { _dict[defaultName] = nil }
    }
}
