import Foundation
@testable import Bucketeer

final class MockLogger: Logger {
    private(set) var debugMessage: String?
    private(set) var warnMessage: String?
    private(set) var error: Error?

    func debug(message: String) {
        print("Test Logger [DEBUG] \(message)")
        self.debugMessage = message
    }

    func warn(message: String) {
        print("Test Logger [WARN] \(message)")
        self.warnMessage = message
    }

    func error(_ error: Error) {
        print("Test Logger [ERROR] \(error)")
        self.error = error
    }
}
