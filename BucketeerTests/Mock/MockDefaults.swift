import Foundation
@testable import Bucketeer

final class MockDefaults: Defaults {
    func bool(forKey defaultName: String) -> Bool {
        return dict[defaultName] as? Bool ?? false
    }

    var dict: [String: Any?] = [:]

    func string(forKey defaultName: String) -> String? {
        return dict[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        dict[defaultName] = value
    }
}
