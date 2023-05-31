import Foundation

enum GetEvaluationsResult {
    case success(GetEvaluationsResponse)
    case failure(error: BKTError, featureTag: String)
}
