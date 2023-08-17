import Foundation
import Bucketeer

final class AppLogger: BKTLogger {
    private var prefix: String {
        ""
    }

    func debug(message: String) {
        print("\(prefix)[DEBUG] \(message)")
    }

    func warn(message: String) {
        print("\(prefix)[WARN] \(message)")
    }

    func error(_ error: Error) {
        print("\(prefix)[ERROR] \(error)")
    }
}
