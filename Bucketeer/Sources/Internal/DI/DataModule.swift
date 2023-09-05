import Foundation

protocol DataModule {
    var config: BKTConfig { get }
    var userHolder: UserHolder { get }
    var apiClient: ApiClient { get }
    var evaluationStorage: EvaluationStorage { get }
    var eventDao: EventDao { get }
    var defaults: Defaults { get }
    var idGenerator: IdGenerator { get }
    var clock: Clock { get }
    var device: Device { get }
}

final class DataModuleImpl: DataModule {

    let user: User
    let config: BKTConfig
    let sqlite: SQLite
    let eventDao: EventDao

    init(user: User, config: BKTConfig) throws {
        self.user = user
        self.config = config
        self.sqlite = try DatabaseOpenHelper.createDatabase(logger: config.logger)
        self.evaluationDao = EvaluationSQLDao(db: sqlite)
        self.eventDao = EventDaoImpl(db: sqlite)
    }

    private(set) lazy var clock: Clock = ClockImpl()
    private(set) lazy var idGenerator: IdGenerator = IdGeneratorImpl()
    private(set) lazy var apiClient: ApiClient = ApiClientImpl(
        apiEndpoint: config.apiEndpoint,
        apiKey: self.config.apiKey,
        featureTag: self.config.featureTag,
        session: URLSession.shared,
        logger: self.config.logger
    )
    private(set) lazy var userHolder: UserHolder = UserHolder(user: self.user)
    private(set) lazy var defaults: Defaults = UserDefaults.standard
    private(set) lazy var device: Device = DeviceImpl()
    // Evaluation Data Access Layer
    private let evaluationDao: EvaluationDao
    private lazy var evaluationMemCacheDao: EvaluationMemCacheDao = EvaluationMemCacheDao()
    private lazy var evaluationUserDefaultsDao: EvaluationUserDefaultsDao = EvaluationUserDefaultDaoImpl(defaults: defaults)
    private(set) lazy var evaluationStorage: EvaluationStorage = EvaluationStorageImpl(
        userId: user.id,
        evaluationDao: evaluationDao,
        evaluationMemCacheDao: evaluationMemCacheDao,
        evaluationUserDefaultsDao: evaluationUserDefaultsDao)
}
