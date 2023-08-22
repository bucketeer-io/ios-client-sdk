import Foundation
import Bucketeer

final class AppLogger: BKTLogger {
    let df = DateFormatter()
    
    private var prefix: String {
        ""
    }

    func debug(message: String) {
        df.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS"
        print("\(prefix)[DEBUG] \(df.string(from: Date())) \(message)")
    }

    func warn(message: String) {
        df.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS"
        print("\(prefix)[WARN] \(df.string(from: Date())) \(message)")
    }

    func error(_ error: Error) {
        df.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS"
        print("\(prefix)[ERROR] \(df.string(from: Date())) \(error)")
    }
}
