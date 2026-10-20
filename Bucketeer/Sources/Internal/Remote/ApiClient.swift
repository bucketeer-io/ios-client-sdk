import Foundation

enum ApiPaths: String {
    case getEvaluations = "get_evaluations"
    case registerEvents = "register_events"
    // A static constant on purpose, not a case. Every case is a request that ApiClientImpl sends
    // and tracks by request id (see the exhaustive switch in ApiClientImpl.getLatestRequestId).
    // The stream is opened by StreamingTask on its own URLSession and never goes through
    // ApiClientImpl, so it has no request id to track. Kept here so all backend paths live in one place.
    static let streamEvaluations = "v1/gateway/stream_evaluations"
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
