import Foundation
@testable import Bucketeer

final class MockComponent: Component {
    var config: BKTConfig
    var userHolder: UserHolder
    var evaluationInteractor: EvaluationInteractor
    var eventInteractor: EventInteractor

    init(config: BKTConfig = .mock1,
         userHolder: UserHolder = UserHolder(user: .mock1),
         evaluationInteractor: EvaluationInteractor = MockEvaluationInteractor(),
         eventInteractor: EventInteractor = MockEventInteractor()) {
        self.config = config
        self.userHolder = userHolder
        self.evaluationInteractor = evaluationInteractor
        self.eventInteractor = eventInteractor
    }
}
