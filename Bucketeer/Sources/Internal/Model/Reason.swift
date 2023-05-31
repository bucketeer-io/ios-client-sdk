import Foundation

struct Reason: Codable, Hashable {
    let type: ReasonType
    var ruleId: String? = ""
}
