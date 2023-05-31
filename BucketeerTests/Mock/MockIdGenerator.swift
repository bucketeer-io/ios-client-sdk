import Foundation
@testable import Bucketeer

final class MockIdGenerator: IdGenerator {
    let identifier: () -> String

    init(identifier: @escaping () -> String) {
        self.identifier = identifier
    }
    init(identifier: String) {
        self.identifier = { () in return identifier }
    }

    func id() -> String {
        return identifier()
    }
}
