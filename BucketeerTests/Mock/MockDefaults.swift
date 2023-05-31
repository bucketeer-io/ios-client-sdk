import Foundation
@testable import Bucketeer

final class MockDefaults: Defaults {
    var dict: [String: Any?] = [:]

    func string(forKey defaultName: String) -> String? {
        return dict[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        dict[defaultName] = value
    }
}
