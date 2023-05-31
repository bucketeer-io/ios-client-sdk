import Foundation

protocol ApiClient {
    func getEvaluations(user: User, userEvaluationsId: String, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?)
    func registerEvents(events: [Event], completion: ((Result<RegisterEventsResponse, BKTError>) -> Void)?)
}

extension ApiClient {
    func getEvaluations(user: User, userEvaluationsId: String, completion: ((GetEvaluationsResult) -> Void)?) {
        getEvaluations(
            user: user,
            userEvaluationsId: userEvaluationsId,
            timeoutMillis: nil,
            completion: completion
        )
    }
}
