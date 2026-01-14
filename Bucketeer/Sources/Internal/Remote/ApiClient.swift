import Foundation

enum ApiPaths: String {
    case getEvaluations = "get_evaluations"
    case registerEvents = "register_events"
}

protocol ApiClient {
    func getEvaluations(
        user: User,
        userEvaluationsId: String,
        timeoutMillis: Int64?,
        condition: UserEvaluationCondition,
        completion: ((GetEvaluationsResult) -> Void)?
    )
    func registerEvents(events: [Event], completion: ((Result<RegisterEventsResponse, BKTError>) -> Void)?)
    func cancelAllOngoingRequest()
}

extension ApiClient {
    func getEvaluations(
        user: User,
        userEvaluationsId: String,
        condition: UserEvaluationCondition,
        completion: ((GetEvaluationsResult) -> Void)?) {
        getEvaluations(
            user: user,
            userEvaluationsId: userEvaluationsId,
            timeoutMillis: nil,
            condition: condition,
            completion: completion
        )
    }

    func cancelAllOngoingRequest() {}
}
