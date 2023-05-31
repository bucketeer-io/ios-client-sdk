import Foundation
import SQLite3

extension SQLite {
    enum Error: Swift.Error, Equatable, CustomNSError, CustomDebugStringConvertible {
        case unknown
        case failedToOpen(Info)
        case failedToPrepare(Info)
        case failedToStep(Info)
        case failedToBind(Info)
        case failedToFinalize(Info)
        case failedToExecute(Info)
        case unsupportedType

        var errorUserInfo: [String: Any] {
            switch self {
            case .failedToOpen(let info),
                    .failedToPrepare(let info),
                    .failedToStep(let info),
                    .failedToBind(let info),
                    .failedToFinalize(let info),
                    .failedToExecute(let info):
                return info.userInfo
            case .unsupportedType:
                return [NSLocalizedDescriptionKey: "Unsupported type"]
            case .unknown:
                return [NSLocalizedDescriptionKey: "Unexpected error"]
            }
        }

        var debugDescription: String {
            switch self {
            case .failedToOpen(let info),
                    .failedToPrepare(let info),
                    .failedToStep(let info),
                    .failedToBind(let info),
                    .failedToFinalize(let info),
                    .failedToExecute(let info):
                return info.debugDescription
            case .unsupportedType:
                return "Unsupported type"
            case .unknown:
                return "Unexpected error"
            }
        }

        struct Info: Equatable, CustomDebugStringConvertible {
            let pointer: OpaquePointer
            let result: Int32

            var userInfo: [String: Any] {
                return [
                    NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(pointer)),
                    "SQLiteHelperErrorResult": self.result
                ]
            }

            var debugDescription: String {
                String(cString: sqlite3_errmsg(pointer))
            }
        }
    }
}
