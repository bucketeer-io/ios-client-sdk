import Foundation

struct UserEvaluationCondition: Codable {
    // https://github.com/bucketeer-io/android-client-sdk/issues/69
    // evaluatedAt: the last time the user was evaluated. The server will return in the get_evaluations response (UserEvaluations.CreatedAt), and it must be saved in the client
    // userAttributesUpdated: when the user attributes change via the customAttributes interface, the userAttributesUpdated field must be set to true in the next request.
    let evaluatedAt: String?
    let userAttributesUpdated: Bool
}
