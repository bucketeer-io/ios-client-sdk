import XCTest
@testable import Bucketeer

/// Covers `EvaluationInteractorImpl.applyStreamedEvaluations`, the entry point streamed
/// (`put`/`patch`) evaluations will use once PR 4 wires up `StreamingTask`. It shares the
/// `writeEvaluations` write path with `fetch`, so this file focuses on what is different
/// about the streamed path: it never clears the user-attributes-updated flag, it respects
/// `shouldNotify`, and it drops a payload whose `createdAt` cannot be read as a number.
///
/// A separate file from `EvaluationInteractorTests`, which is already close to
/// SwiftLint's `file_length` limit under `swiftlint --strict`.
@available(iOS 13, *)
final class EvaluationInteractorStreamingTests: XCTestCase {

    private func makeInteractor(
        storage: MockEvaluationStorage,
        logger: MockLogger = MockLogger()
    ) -> EvaluationInteractorImpl {
        EvaluationInteractorImpl(
            apiClient: MockApiClient(),
            evaluationStorage: storage,
            idGenerator: MockIdGenerator(identifier: ""),
            featureTag: BKTConfig.mock1.featureTag,
            logger: logger
        )
    }

    func testApplyStreamedEvaluationsUpsertsAndNotifies() {
        let expectation = XCTestExpectation(description: "update + notify")
        expectation.expectedFulfillmentCount = 2
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            updateHandler: { evaluations, archivedFeatureIds, evaluatedAt in
                XCTAssertEqual(evaluations, UserEvaluations.mock1Upsert.evaluations)
                XCTAssertEqual(archivedFeatureIds, [])
                XCTAssertEqual(evaluatedAt, UserEvaluations.mock1Upsert.createdAt)
                expectation.fulfill()
                return true
            },
            deleteAllAndInsertHandler: { _ in XCTFail("not a forceUpdate response") }
        )
        let interactor = makeInteractor(storage: storage)
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            expectation.fulfill()
        }))

        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: .mock1Upsert, userEvaluationsId: UserEvaluations.mock1Upsert.id)
        )

        XCTAssertEqual(storage.currentEvaluationsId, UserEvaluations.mock1Upsert.id)
        XCTAssertEqual(storage.evaluatedAt, UserEvaluations.mock1Upsert.createdAt)
        wait(for: [expectation], timeout: 1)
    }

    func testApplyStreamedEvaluationsForceUpdateDeletesAllAndNotifies() {
        let expectation = XCTestExpectation(description: "deleteAllAndInsert + notify")
        expectation.expectedFulfillmentCount = 2
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            updateHandler: { _, _, _ in
                XCTFail("forceUpdate must not call update()")
                return false
            },
            deleteAllAndInsertHandler: { evaluations in
                XCTAssertEqual(evaluations, UserEvaluations.mock1ForceUpdate.evaluations)
                expectation.fulfill()
            }
        )
        let interactor = makeInteractor(storage: storage)
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            expectation.fulfill()
        }))

        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: .mock1ForceUpdate, userEvaluationsId: UserEvaluations.mock1ForceUpdate.id)
        )

        wait(for: [expectation], timeout: 1)
    }

    func testApplyStreamedEvaluationsDropsUnreadableCreatedAt() {
        let notifyExpectation = XCTestExpectation(description: "listener must not fire")
        notifyExpectation.isInverted = true
        let logger = MockLogger()
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            updateHandler: { _, _, _ in
                XCTFail("must not write: createdAt is unreadable")
                return false
            },
            deleteAllAndInsertHandler: { _ in XCTFail("must not write: createdAt is unreadable") }
        )
        let interactor = makeInteractor(storage: storage, logger: logger)
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            notifyExpectation.fulfill()
        }))

        let unreadable = UserEvaluations(
            id: "user_evaluation_unreadable",
            evaluations: [.mock1],
            createdAt: "not-a-number",
            forceUpdate: false,
            archivedFeatureIds: []
        )
        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: unreadable, userEvaluationsId: unreadable.id)
        )

        XCTAssertEqual(storage.currentEvaluationsId, "", "must not have written")
        XCTAssertNotNil(logger.warnMessage)
        XCTAssertTrue(logger.warnMessage?.contains("not-a-number") ?? false)
        wait(for: [notifyExpectation], timeout: 0.3)
    }

    func testApplyStreamedEvaluationsDoesNotNotifyWhenShouldNotifyIsFalse() {
        let writeExpectation = XCTestExpectation(description: "write still lands")
        let notifyExpectation = XCTestExpectation(description: "listener must not fire")
        notifyExpectation.isInverted = true
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            updateHandler: { _, _, _ in
                writeExpectation.fulfill()
                return true
            }
        )
        let interactor = makeInteractor(storage: storage)
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            notifyExpectation.fulfill()
        }))

        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: .mock1Upsert, userEvaluationsId: UserEvaluations.mock1Upsert.id),
            shouldNotify: { false }
        )

        wait(for: [writeExpectation], timeout: 1)
        XCTAssertEqual(storage.currentEvaluationsId, UserEvaluations.mock1Upsert.id, "the write must still land")
        wait(for: [notifyExpectation], timeout: 0.3)
    }

    func testApplyStreamedEvaluationsDoesNotNotifyWhenWriteIsStale() {
        let notifyExpectation = XCTestExpectation(description: "listener must not fire")
        notifyExpectation.isInverted = true
        var shouldNotifyWasEvaluated = false
        let storage = MockEvaluationStorage(userId: User.mock1.id)
        storage.isStaleWriteHandler = { _ in true }
        let interactor = makeInteractor(storage: storage)
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            notifyExpectation.fulfill()
        }))

        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: .mock1Upsert, userEvaluationsId: UserEvaluations.mock1Upsert.id),
            shouldNotify: {
                shouldNotifyWasEvaluated = true
                return true
            }
        )

        XCTAssertEqual(storage.currentEvaluationsId, "", "a stale write must not land")
        XCTAssertFalse(shouldNotifyWasEvaluated, "shouldNotify must not be evaluated for a write that never happened")
        wait(for: [notifyExpectation], timeout: 0.3)
    }

    func testApplyStreamedEvaluationsDoesNotClearUserAttributesUpdated() {
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            updateHandler: { _, _, _ in true }
        )
        let interactor = makeInteractor(storage: storage)

        interactor.setUserAttributesUpdated()
        XCTAssertTrue(storage.userAttributesState.isUpdated)

        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: .mock1Upsert, userEvaluationsId: UserEvaluations.mock1Upsert.id)
        )

        XCTAssertTrue(
            storage.userAttributesState.isUpdated,
            "streamed data must never clear the flag: only fetch()'s polling path may, since only it knows its request carried the flag"
        )
    }

    func testApplyStreamedEvaluationsSwallowsStorageError() {
        let notifyExpectation = XCTestExpectation(description: "listener must not fire")
        notifyExpectation.isInverted = true
        let logger = MockLogger()
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            updateHandler: { _, _, _ in throw NSError(domain: "db", code: 100, userInfo: [:]) }
        )
        let interactor = makeInteractor(storage: storage, logger: logger)
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            notifyExpectation.fulfill()
        }))

        interactor.applyStreamedEvaluations(
            GetEvaluationsResponse(evaluations: .mock1Upsert, userEvaluationsId: UserEvaluations.mock1Upsert.id)
        )

        XCTAssertNotNil(logger.error)
        wait(for: [notifyExpectation], timeout: 0.3)
    }

    func testFetchForceUpdateDoesNotNotifyWhenWriteIsStale() {
        let completionExpectation = XCTestExpectation(description: "completion still receives success")
        let notifyExpectation = XCTestExpectation(description: "listener must not fire")
        notifyExpectation.isInverted = true
        let api = MockApiClient(getEvaluationsHandler: { _, _, _, _, completion in
            completion?(.success(GetEvaluationsResponse(evaluations: .mock1ForceUpdate, userEvaluationsId: UserEvaluations.mock1ForceUpdate.id)))
        })
        let storage = MockEvaluationStorage(userId: User.mock1.id)
        storage.isStaleWriteHandler = { _ in true }
        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: MockIdGenerator(identifier: ""),
            featureTag: BKTConfig.mock1.featureTag
        )
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            notifyExpectation.fulfill()
        }))

        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success:
                completionExpectation.fulfill()
            case .failure(let error, _):
                XCTFail("\(error)")
            }
        }

        wait(for: [completionExpectation], timeout: 1)
        wait(for: [notifyExpectation], timeout: 0.3)
    }

    func testFetchForceUpdateStillNotifiesWhenWriteLands() {
        let expectation = XCTestExpectation(description: "completion + notify")
        expectation.expectedFulfillmentCount = 2
        let api = MockApiClient(getEvaluationsHandler: { _, _, _, _, completion in
            completion?(.success(GetEvaluationsResponse(evaluations: .mock1ForceUpdate, userEvaluationsId: UserEvaluations.mock1ForceUpdate.id)))
        })
        let storage = MockEvaluationStorage(
            userId: User.mock1.id,
            deleteAllAndInsertHandler: { _ in }
        )
        let interactor = EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: MockIdGenerator(identifier: ""),
            featureTag: BKTConfig.mock1.featureTag
        )
        interactor.addUpdateListener(listener: MockEvaluationUpdateListener(handler: {
            expectation.fulfill()
        }))

        interactor.fetch(user: .mock1) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error, _):
                XCTFail("\(error)")
            }
        }

        wait(for: [expectation], timeout: 1)
    }
}
