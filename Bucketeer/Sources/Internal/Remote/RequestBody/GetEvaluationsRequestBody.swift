import Foundation

struct GetEvaluationsRequestBody: Codable {
    let tag: String
    let user: User
    let userEvaluationsId: String
    let sourceId: SourceID
    let userEvaluationCondition: UserEvaluationCondition
    // noted: we didn't set the default value to prevent the warning about Decodeable will not work
    // error message "Immutable property will not be decoded because it is declared with an initial value which cannot be overwritten"
    let sdkVersion: String
}
