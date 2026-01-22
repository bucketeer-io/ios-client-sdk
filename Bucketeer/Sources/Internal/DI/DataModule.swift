import Foundation

protocol DataModule {
    var config: BKTConfig { get }
    var userHolder: UserHolder { get }
    var apiClient: ApiClient { get }
    var evaluationStorage: EvaluationStorage { get }
    var eventSQLDao: EventSQLDao { get }
    var defaults: Defaults { get }
    var idGenerator: IdGenerator { get }
    var clock: Clock { get }
    var device: Device { get }
}

final class DataModuleImpl: DataModule {

    let user: User
    let config: BKTConfig
    let sqlite: SQLite
    let eventSQLDao: EventSQLDao
    let dispatchQueue: DispatchQueue

    init(user: User, config: BKTConfig, dispatchQueue: DispatchQueue) throws {
        self.user = user
        self.config = config
        self.sqlite = try DatabaseOpenHelper.createDatabase(logger: config.logger)
        self.evaluationDao = EvaluationSQLDaoImpl(db: sqlite)
        self.eventSQLDao = EventSQLDaoImpl(db: sqlite)
        self.dispatchQueue = dispatchQueue
    }

    private(set) lazy var clock: Clock = ClockImpl()
    private(set) lazy var idGenerator: IdGenerator = IdGeneratorImpl()
    private(set) lazy var apiClient: ApiClient = ApiClientImpl(
        apiEndpoint: config.apiEndpoint,
        apiKey: self.config.apiKey,
        featureTag: self.config.featureTag,
        sdkInfo: self.config.toSDKInfo(),
        session: URLSession(configuration: .default),
        retrier: Retrier(queue: dispatchQueue),
        logger: self.config.logger
    )
    private(set) lazy var userHolder: UserHolder = UserHolder(user: self.user)
    private(set) lazy var defaults: Defaults = UserDefaults.standard
    private(set) lazy var device: Device = DeviceImpl()
    // Evaluation Data Access Layer
    private let evaluationDao: EvaluationSQLDao
    private lazy var evaluationMemCacheDao: EvaluationMemCacheDao = EvaluationMemCacheDao()
    private lazy var evaluationUserDefaultsDao: EvaluationUserDefaultsDao = EvaluationUserDefaultDaoImpl(defaults: defaults)
    private(set) lazy var evaluationStorage: EvaluationStorage = EvaluationStorageImpl(
        userId: user.id,
        evaluationDao: evaluationDao,
        evaluationMemCacheDao: evaluationMemCacheDao,
        evaluationUserDefaultsDao: evaluationUserDefaultsDao)
}
