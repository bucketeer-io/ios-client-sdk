import Foundation

struct UserEvaluations: Hashable, Codable {
    let id: String
    let evaluations: [Evaluation]
    let createdAt: String
    let forceUpdate: Bool
    let archivedFeatureIds: [String]
}
