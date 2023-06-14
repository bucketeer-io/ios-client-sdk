import Foundation

enum ReasonType: String, Codable, Hashable {
    case target = "TARGET"
    case rule = "RULE"
    case `default` = "DEFAULT"
    case client = "CLIENT"
    case offVariation = "OFF_VARIATION"
    case prerequisite = "PREREQUISITE"
}
