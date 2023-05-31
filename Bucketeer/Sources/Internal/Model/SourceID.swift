import Foundation

enum SourceID: Int, Codable, Hashable {
    case unknown = 0
    case android = 1
    case ios = 2
    case web = 3
    case goalBatch = 4
    case goServer = 5
    case nodeServer = 6
}
