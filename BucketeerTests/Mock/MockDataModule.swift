import Foundation
@testable import Bucketeer

struct MockDataModule: DataModule {
    var config: BKTConfig = .mock1
    var userHolder: UserHolder = .init(user: .mock1)
    var apiClient: ApiClient = MockApiClient(getEvaluationsHandler: nil, registerEventsHandler: nil)
    var evaluationDao: EvaluationDao = MockEvaluationDao(putHandler: nil, getHandler: nil, deleteAllAndInsertHandler: nil)
    var eventDao: EventDao = MockEventDao(addEventsHandler: nil, getEventsHandler: nil, deleteEventsHandler: nil)
    var defaults: Defaults = MockDefaults()
    var idGenerator: IdGenerator = MockIdGenerator(identifier: "id")
    var clock: Clock = MockClock(timestamp: 1)
    var device: Device = MockDevice()
}
