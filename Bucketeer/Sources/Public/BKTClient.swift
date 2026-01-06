import Foundation

public class BKTClient {
    static var `default`: BKTClient!
    private static let concurrentQueue = DispatchQueue(label: "io.bucketeer.concurrentQueue")
    let component: Component
    let dispatchQueue: DispatchQueue
    private(set) var taskScheduler: TaskScheduler?

    init(dataModule: DataModule, dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue
        self.component = ComponentImpl(dataModule: dataModule)
    }

    func getBKTEvaluationDetails<T:Equatable>(featureId: String, defaultValue: T) -> BKTEvaluationDetails<T> {
        component.config.logger?.debug(message: "BKTClient.getVariationDetail(featureId = \(featureId), defaultValue = \(defaultValue) called")
        let raw = component.evaluationInteractor.getLatest(
            userId: component.userHolder.userId,
            featureId: featureId
        )
        let user = component.userHolder.user
        let featureTag = component.config.featureTag

        guard let raw = raw, let value: T = raw.getVariationValue(
            logger: component.config.logger
        ) else {
            execute {
                try self.component.eventInteractor.trackDefaultEvaluationEvent(
                    featureTag: featureTag,
                    user: user,
                    featureId: featureId
                )
            }
            return BKTEvaluationDetails.newDefaultInstance(
                featureId: featureId,
                userId: user.id,
                defaultValue: defaultValue
            )
        }
        execute {
            try self.component.eventInteractor.trackEvaluationEvent(
                featureTag: featureTag,
                user: user,
                evaluation: raw
            )
        }

        return BKTEvaluationDetails(
            featureId: featureId,
            featureVersion: raw.featureVersion,
            userId: raw.userId,
            variationId: raw.variationId,
            variationName: raw.variationName,
            variationValue: value,
            reason: BKTEvaluationDetails<T>.Reason.fromString(value: raw.reason.type.rawValue)
        )
    }

    fileprivate func scheduleTasks() {
        self.taskScheduler = TaskScheduler(component: component, dispatchQueue: dispatchQueue)
    }

    func refreshCache() {
        do {
            try component.evaluationInteractor.refreshCache()
        } catch let error {
            component.config.logger?.error(error)
        }
    }

    func execute(_ handler: @escaping () throws -> Void) {
        dispatchQueue.async {
            do {
                try handler()
            } catch let error {
                self.component.config.logger?.error(error)
            }
        }
    }

    private func destroy() {
        taskScheduler?.invalidate()
        taskScheduler = nil
        execute { [weak self] in
            // must destroy in the intenal queue to prevent race condition
            self?.component.destroy()
        }
    }
}

extension BKTClient {
    public static func initialize(config: BKTConfig, user: BKTUser, timeoutMillis: Int64 = 5000, completion: ((BKTError?) -> Void)? = nil) throws {
        concurrentQueue.sync {
            let initializeCompletion : (BKTError?) -> Void = { err in
                DispatchQueue.main.async {
                    completion?(err)
                }
            }

            guard BKTClient.default == nil else {
                config.logger?.warn(message: "BKTClient is already initialized. Not sure if the initial fetch has finished")
                initializeCompletion(nil)
                return
            }
            do {
                let dispatchQueue = DispatchQueue(label: "io.bucketeer.taskQueue")
                let dataModule = try DataModuleImpl(user: user.toUser(), config: config)
                let client = BKTClient(dataModule: dataModule, dispatchQueue: dispatchQueue)
                client.scheduleTasks()
                client.execute { [weak client] in
                    client?.refreshCache()
                    client?.fetchEvaluations(timeoutMillis: timeoutMillis, completion: initializeCompletion)
                }
                BKTClient.default = client
            } catch let error {
                config.logger?.error(error)
                initializeCompletion(error as? BKTError ?? BKTError.unknown(message: "unknown error while returning the initialize completion", error: error))
            }
        }
    }

    public static func destroy() throws {
        concurrentQueue.sync {
            BKTClient.default?.destroy()
            BKTClient.default = nil
        }
    }

    // Please make sure the BKTClient is initialize before access it
    public static var shared: BKTClient {
        get throws {
            // We do not want to crash the SDK's consumer app on runtime by using fatalError().
            // So let the app has a chance to catch this exception
            // The same behavior with the Android SDK
            guard BKTClient.default != nil else {
                throw BKTError.illegalState(message: "BKTClient is not initialized")
            }
            return BKTClient.default
        }
    }

    public func boolVariation(featureId: String, defaultValue: Bool) -> Bool {
        return boolVariationDetails(featureId: featureId, defaultValue: defaultValue).variationValue
    }

    public func boolVariationDetails(featureId: String, defaultValue: Bool) -> BKTEvaluationDetails<Bool> {
        return getBKTEvaluationDetails(featureId: featureId, defaultValue: defaultValue)
    }

    public func intVariation(featureId: String, defaultValue: Int) -> Int {
        return intVariationDetails(featureId: featureId, defaultValue: defaultValue).variationValue
    }

    public func intVariationDetails(featureId: String, defaultValue: Int) -> BKTEvaluationDetails<Int> {
        return getBKTEvaluationDetails(featureId: featureId, defaultValue: defaultValue)
    }

    public func doubleVariation(featureId: String, defaultValue: Double) -> Double {
        return doubleVariationDetails(featureId: featureId, defaultValue: defaultValue).variationValue
    }

    public func doubleVariationDetails(featureId: String, defaultValue: Double) -> BKTEvaluationDetails<Double> {
        return getBKTEvaluationDetails(featureId: featureId, defaultValue: defaultValue)
    }

    public func stringVariation(featureId: String, defaultValue: String) -> String {
        return stringVariationDetails(featureId: featureId, defaultValue: defaultValue).variationValue
    }

    public func stringVariationDetails(featureId: String, defaultValue: String) -> BKTEvaluationDetails<String> {
        return getBKTEvaluationDetails(featureId: featureId, defaultValue: defaultValue)
    }

    public func objectVariation(featureId: String, defaultValue: BKTValue) -> BKTValue {
        return objectVariationDetails(featureId: featureId, defaultValue: defaultValue).variationValue
    }

    public func objectVariationDetails(featureId: String, defaultValue:BKTValue)
    -> BKTEvaluationDetails<BKTValue> {
        return getBKTEvaluationDetails(featureId: featureId, defaultValue: defaultValue)
    }

    @available(*, deprecated, message: "use objectVariation(featureId:, defaultValue:) instead")
    public func jsonVariation(featureId: String, defaultValue: [String: AnyHashable]) -> [String: AnyHashable] {
        return getBKTEvaluationDetails(featureId: featureId, defaultValue: defaultValue).variationValue
    }

    public func track(goalId: String, value: Double = 0.0) {
        let user = component.userHolder.user
        let featureTag = component.config.featureTag
        execute {
            try self.component.eventInteractor.trackGoalEvent(
                featureTag: featureTag,
                user: user,
                goalId: goalId,
                value: value
            )
        }
    }

    public func currentUser() -> BKTUser? {
        component.userHolder.user.toBKTUser()
    }

    public func updateUserAttributes(attributes: [String: String]) {
        component.userHolder.updateAttributes { _ in
            attributes
        }
        execute {
            self.component.evaluationInteractor.setUserAttributesUpdated()
        }
    }

    public func fetchEvaluations(timeoutMillis: Int64? = nil, completion: ((BKTError?) -> Void)? = nil) {
        let fetchEvaluationsCompletion : (BKTError?) -> Void = { err in
            DispatchQueue.main.async {
                completion?(err)
            }
        }
        execute {
            Self.fetchEvaluationsSync(
                component: self.component,
                dispatchQueue: self.dispatchQueue,
                timeoutMillis: timeoutMillis,
                completion: fetchEvaluationsCompletion
            )
        }
    }

    public func flush(completion: ((BKTError?) -> Void)? = nil) {
        let flushCompletion : (BKTError?) -> Void = { err in
            DispatchQueue.main.async {
                completion?(err)
            }
        }
        execute {
            Self.flushSync(
                component: self.component,
                completion: flushCompletion
            )
        }
    }

    @available(*, deprecated, message: "use stringVariationDetails(featureId:, defaultValue:) instead")
    public func evaluationDetails(featureId: String) -> BKTEvaluation? {
        let userId = self.component.userHolder.userId
        let evaluation = self.component.evaluationInteractor.getLatest(userId: userId, featureId: featureId)
        guard let evaluation = evaluation else {
            return nil
        }
        return BKTEvaluation(
            id: evaluation.id,
            featureId: evaluation.featureId,
            featureVersion: evaluation.featureVersion,
            userId: evaluation.userId,
            variationId: evaluation.variationId,
            variationName: evaluation.variationName,
            variationValue: evaluation.variationValue,
            reason: BKTEvaluation.Reason(rawValue: evaluation.reason.type.rawValue) ?? .default
        )
    }

    @discardableResult
    public func addEvaluationUpdateListener(listener: EvaluationUpdateListener) -> String {
        component.evaluationInteractor.addUpdateListener(listener: listener)
    }

    public func removeEvaluationUpdateListener(key: String) {
        component.evaluationInteractor.removeUpdateListener(key: key)
    }

    public func clearEvaluationUpdateListeners() {
        component.evaluationInteractor.clearUpdateListeners()
    }
}

public protocol EvaluationUpdateListener {
    func onUpdate()
}

extension BKTClient {
    static func fetchEvaluationsSync(
        component: Component,
        dispatchQueue: DispatchQueue,
        timeoutMillis: Int64?,
        completion: ((BKTError?) -> Void)?
    ) {
        component.evaluationInteractor.fetch(user: component.userHolder.user, timeoutMillis: timeoutMillis, completion: { result in
            dispatchQueue.async {
                do {
                    let interactor = component.eventInteractor
                    switch result {
                    case .success(let response):
                        try interactor.trackFetchEvaluationsSuccess(
                            featureTag: response.featureTag,
                            seconds: response.seconds,
                            sizeByte: response.sizeByte
                        )
                        completion?(nil)
                    case .failure(let error, let featureTag):
                        try interactor.trackFetchEvaluationsFailure(
                            featureTag: featureTag,
                            error: error
                        )
                        completion?(error)
                    }
                } catch let error {
                    component.config.logger?.error(error)
                    completion?(error as? BKTError)
                }
            }
        })
    }

    static func flushSync(component: Component, completion: ((BKTError?) -> Void)?) {
        component.eventInteractor.sendEvents(force: true) { result in
            switch result {
            case .success:
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }
}
