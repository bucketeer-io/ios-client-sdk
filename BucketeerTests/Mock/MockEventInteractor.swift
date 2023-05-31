import Foundation
@testable import Bucketeer

final class MockEventInteractor: EventInteractor {
    typealias SendEventsHandler = (_ force: Bool, _ completion: ((Result<Bool, BKTError>) -> Void)?) -> Void
    typealias TrackEvaluationSuccessHandler = (_ featureTag: String, _ seconds: Double, _ sizeByte: Int64) throws -> Void
    typealias TrackEvaluationFailureHandler = (_ featureTag: String, _ error: BKTError) throws -> Void
    typealias TrackRegisterEventFailureHandler = (_ error: BKTError) throws -> Void

    var eventUpdateListener: EventUpdateListener?
    var sendEventsHandler: SendEventsHandler?
    var trackEvaluationSuccessHandler: TrackEvaluationSuccessHandler?
    var trackEvaluationFailureHandler: TrackEvaluationFailureHandler?
    var trackRegisterEventFailureHandler: TrackRegisterEventFailureHandler?

    init(eventUpdateListener: EventUpdateListener? = nil,
         sendEventsHandler: SendEventsHandler? = nil,
         trackEvaluationSuccessHandler: TrackEvaluationSuccessHandler? = nil,
         trackEvaluationFailureHandler: TrackEvaluationFailureHandler? = nil,
         trackRegisterEventFailureHandler: TrackRegisterEventFailureHandler? = nil) {
        self.eventUpdateListener = eventUpdateListener
        self.sendEventsHandler = sendEventsHandler
        self.trackEvaluationSuccessHandler = trackEvaluationSuccessHandler
        self.trackEvaluationFailureHandler = trackEvaluationFailureHandler
        self.trackRegisterEventFailureHandler = trackRegisterEventFailureHandler
    }

    func set(eventUpdateListener: EventUpdateListener?) {
        self.eventUpdateListener = eventUpdateListener
    }
    func trackEvaluationEvent(featureTag: String, user: User, evaluation: Evaluation) throws {
    }
    func trackDefaultEvaluationEvent(featureTag: String, user: User, featureId: String) throws {
    }
    func trackGoalEvent(featureTag: String, user: User, goalId: String, value: Double) throws {
    }
    func trackFetchEvaluationsSuccess(featureTag: String, seconds: Double, sizeByte: Int64) throws {
        try trackEvaluationSuccessHandler?(featureTag, seconds, sizeByte)
    }
    func trackFetchEvaluationsFailure(featureTag: String, error: BKTError) throws {
        try trackEvaluationFailureHandler?(featureTag, error)
    }
    func trackRegisterEventsFailure(error: BKTError) throws {
        try trackRegisterEventFailureHandler?(error)
    }
    func sendEvents(force: Bool, completion: ((Result<Bool, BKTError>) -> Void)?) {
        sendEventsHandler?(force, completion)
    }
}
