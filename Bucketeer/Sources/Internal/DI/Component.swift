import Foundation

protocol Component: AnyObject {
    var config: BKTConfig { get }
    var userHolder: UserHolder { get }
    var evaluationInteractor: EvaluationInteractor { get }
    var eventInteractor: EventInteractor { get }
    
    func destroy()
}

extension Component {
    func destroy() {}
}

final class ComponentImpl: Component {
    let dataModule: DataModule
    let evaluationInteractor: EvaluationInteractor
    let eventInteractor: EventInteractor

    init(dataModule: DataModule) {
        self.dataModule = dataModule
        self.evaluationInteractor = EvaluationInteractorImpl(
            apiClient: dataModule.apiClient,
            evaluationStorage: dataModule.evaluationStorage,
            idGenerator: dataModule.idGenerator,
            featureTag: dataModule.config.featureTag
        )
        self.eventInteractor = EventInteractorImpl(
            sdkVersion: dataModule.config.sdkVersion,
            appVersion: dataModule.config.appVersion,
            device: dataModule.device,
            eventsMaxBatchQueueCount: dataModule.config.eventsMaxQueueSize,
            apiClient: dataModule.apiClient,
            eventDao: dataModule.eventDao,
            clock: dataModule.clock,
            idGenerator: dataModule.idGenerator,
            logger: dataModule.config.logger,
            featureTag: dataModule.config.featureTag
        )
    }

    var config: BKTConfig {
        dataModule.config
    }

    var userHolder: UserHolder {
        dataModule.userHolder
    }

    func destroy() {
        eventInteractor.set(eventUpdateListener: nil)
        evaluationInteractor.clearUpdateListeners()
        dataModule.apiClient.cancelAllOngoingRequest()
    }
}
