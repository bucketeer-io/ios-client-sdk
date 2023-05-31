import Foundation

struct GetEvaluationsRequestBody: Codable {
    let tag: String
    let user: User
    let userEvaluationsId: String
    let sourceId: SourceID
}
