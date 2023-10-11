import Foundation

struct UserEvaluations: Hashable, Codable {
    // note: should check if we could using `let`
    let id: String
    let evaluations: [Evaluation]
    let createdAt: String
    let forceUpdate: Bool
    let archivedFeatureIds: [String]
}
