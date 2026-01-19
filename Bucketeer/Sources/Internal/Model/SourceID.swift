import Foundation

enum SourceID: Int, Codable, Hashable {
    case unknown = 0
    case android = 1
    case ios = 2
    case web = 3
    case goalBatch = 4
    case goServer = 5
    case nodeServer = 6
    case flutter = 8
    case react = 9
    case reactNative = 10
    case openFeatureKotlin = 100
    case openFeatureSwift = 101
    case openFeatureJavaScript = 102
    case openFeatureGo = 103
    case openFeatureNode = 104
}
