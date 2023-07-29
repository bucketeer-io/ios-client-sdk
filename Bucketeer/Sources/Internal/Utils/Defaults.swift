import Foundation

protocol Defaults {
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: Defaults {}
