import Foundation

protocol IdGenerator {
    func id() -> String
}

final class IdGeneratorImpl: IdGenerator {
    func id() -> String {
        return UUID().uuidString
    }
}
