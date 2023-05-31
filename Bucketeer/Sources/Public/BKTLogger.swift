import Foundation

internal typealias Logger = BKTLogger
public protocol BKTLogger {
    func debug(message: String)
    func warn(message: String)
    func error(_ error: Error)
}
