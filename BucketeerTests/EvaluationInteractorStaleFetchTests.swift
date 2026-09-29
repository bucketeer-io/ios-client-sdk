import XCTest
@testable import Bucketeer

/// Covers what `EvaluationInteractorImpl.fetch` does with the user-attributes-updated flag
/// when the storage staleness guard skips the poll's reply (PR #130, review comment
/// r4114422446).
///
/// The rule under test: if a poll's reply is skipped as stale, the flag must stay on.
///
/// Why it matters: while the flag is on, each poll tells the server "the user's attributes
/// changed, re-evaluate everything for them". The reply to that request is what carries
/// the flag values for the new attributes. If that reply is skipped and the flag is cleared
/// anyway, later polls go out with the flag off, nothing asks the server to re-evaluate
/// again, and the stored values can stay computed for the old attributes. (That last part
/// assumes the server does not re-evaluate on its own when the flag is off; not verified
/// against the server.)
///
/// How reachable this is today: iOS polls take turns on the SDK queue, and
/// `ApiClientImpl.sendInternal` holds that queue until the reply is handled. So a poll's
/// reply can only be older than what is stored if something saved newer data while the
/// poll was waiting. With polling alone that needs, for example, server machines whose
/// clocks disagree. Once streaming ships, it could also be a streamed payload saved off the
/// SDK queue. So this is a safety check, for the same reason `writeLock` exists: the guard
/// must stay correct even if the "everything runs on the SDK queue" assumption breaks.
///
/// How the tests get there: instead of racing two network calls, each test prefills the
/// real `EvaluationStorageImpl` with a stamp newer than the reply, so the real guard makes
/// the skip decision. `MockApiClient` replies synchronously, so every check can run
/// straight after `fetch`.
///
/// A separate file from `EvaluationInteractorTests`, which is already close to
/// SwiftLint's `file_length` limit under `swiftlint --strict`.
@available(iOS 13, *)
final class EvaluationInteractorStaleFetchTests: XCTestCase {

    /// Stamp of the data already in storage: newer than every reply fixture used below
    /// (`mock1ForceUpdate` and `mock1Upsert` are both stamped "1690798021").
    private let storedEvaluatedAt = "1690798100"
    private let storedEvaluationsId = "evaluations_already_stored"
    /// Must differ from `storedEvaluationsId`: a reply with the same id makes `fetch` take
    /// its "Nothing to sync" early return and never reach the write.
    private let replyEvaluationsId = "evaluations_from_reply"

    /// User defaults as a running app would have them. The feature tag must match the
    /// config: creating the interactor compares the two, and on a mismatch it clears the
    /// stored evaluations id, which would break the "stale reply must not be stored" checks.
    private func makeUserDefsDao(evaluatedAt: String) -> MockEvaluationUserDefaultsDao {
        let userDefsDao = MockEvaluationUserDefaultsDao()
        userDefsDao.featureTag = BKTConfig.mock1.featureTag
        userDefsDao.evaluatedAt = evaluatedAt
        userDefsDao.currentEvaluationsId = storedEvaluationsId
        return userDefsDao
    }

    /// Real storage already holding data stamped `storedEvaluatedAt`. The SQL mock fails
    /// the test on any write, because every reply sent to this storage is older and must be
    /// skipped. Reads return nothing, which the storage's init needs for `refreshCache`.
    private func makeStorageHoldingNewerData() -> EvaluationStorageImpl {
        let sqlDao = MockEvaluationSQLDao(
            putHandler: { _ in XCTFail("stale reply must not be written") },
            getHandler: { _ in [] },
            deleteAllHandler: { _ in XCTFail("stale reply must not be written") },
            startTransactionHandler: { _ in XCTFail("stale reply must not open a transaction") }
        )
        return EvaluationStorageImpl(
            userId: User.mock1.id,
            evaluationDao: sqlDao,
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: makeUserDefsDao(evaluatedAt: storedEvaluatedAt)
        )
    }

    /// Answers each request with the next reply in `replies`, and reports the
    /// `userAttributesUpdated` value each request carried, in order.
    private func makeApi(
        replies: [UserEvaluations],
        sentFlags: @escaping (Bool) -> Void
    ) -> MockApiClient {
        var remaining = replies
        return MockApiClient(getEvaluationsHandler: { [replyEvaluationsId] _, _, _, condition, completion in
            sentFlags(condition.userAttributesUpdated)
            guard !remaining.isEmpty else {
                XCTFail("unexpected extra request")
                return
            }
            completion?(.success(GetEvaluationsResponse(
                evaluations: remaining.removeFirst(),
                userEvaluationsId: replyEvaluationsId
            )))
        })
    }

    private func makeInteractor(api: MockApiClient, storage: EvaluationStorage) -> EvaluationInteractorImpl {
        EvaluationInteractorImpl(
            apiClient: api,
            evaluationStorage: storage,
            idGenerator: MockIdGenerator(identifier: ""),
            featureTag: BKTConfig.mock1.featureTag
        )
    }

    /// Runs one poll and waits for it to finish.
    private func poll(_ interactor: EvaluationInteractorImpl) {
        let done = expectation(description: "poll finished")
        interactor.fetch(user: .mock1) { _ in done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    /// The app changed user attributes, then polled once, and the server answered with
    /// `reply`. Also checks the setup itself: the request must carry the flag, or the
    /// test would not be exercising the attribute-change path at all.
    private func pollAfterAttributeChange(
        reply: UserEvaluations,
        storage: EvaluationStorageImpl,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var sent: [Bool] = []
        let interactor = makeInteractor(
            api: makeApi(replies: [reply], sentFlags: { sent.append($0) }),
            storage: storage
        )
        interactor.setUserAttributesUpdated()
        poll(interactor)
        XCTAssertEqual(sent, [true], "setup: the poll must carry the flag", file: file, line: line)
    }

    /// Issue: a full-snapshot reply (`forceUpdate: true`, written by `deleteAllAndInsert`)
    /// that the staleness guard skips must not clear the flag.
    ///
    /// A request with the flag on is expected to get a full snapshot back (the JS SDK's
    /// notes say so), so this is the most likely shape of the skipped reply. For this reply
    /// type, `deleteAllAndInsert` reports the skip as `.skippedStale`, and `fetch` must keep
    /// the flag on in that case instead of clearing it.
    ///
    /// Setup: storage holds data stamped "1690798100". The app changes attributes (flag
    /// on), then polls. The reply is stamped "1690798021", which is older.
    ///
    /// Verifies:
    /// - The reply really was skipped: the stored stamp and id are unchanged, and the SQL
    ///   mock saw no write. This shows the guard works, so a failure below is about the
    ///   flag and nothing else.
    /// - The flag is still on, so the next poll will ask the server again.
    func testStaleForceUpdateReplyKeepsUserAttributesUpdatedFlag() {
        let storage = makeStorageHoldingNewerData()
        XCTAssertLessThan(
            Int64(UserEvaluations.mock1ForceUpdate.createdAt)!, Int64(storedEvaluatedAt)!,
            "setup: the reply must be older than the stored data"
        )

        pollAfterAttributeChange(reply: .mock1ForceUpdate, storage: storage)

        XCTAssertEqual(storage.evaluatedAt, storedEvaluatedAt, "stale reply must not be stored")
        XCTAssertEqual(storage.currentEvaluationsId, storedEvaluationsId, "stale reply must not be stored")
        XCTAssertTrue(
            storage.userAttributesState.isUpdated,
            "the re-evaluation for the new attributes was skipped as stale, so the flag must stay on"
        )
    }

    /// Issue: the same as the full-snapshot test, for a diff reply (`forceUpdate: false`,
    /// written by `update`).
    ///
    /// This branch needs its own test because `update` has two outcomes that both mean "no
    /// listener callback": `.skippedStale` and `.landed(shouldNotify: false)` (saved, but
    /// the reply was empty). Only the first must keep the flag on. A fix that only covers
    /// `deleteAllAndInsert`, or that treats those two outcomes the same, fails here.
    ///
    /// Setup: storage holds data stamped "1690798100". The app changes attributes (flag
    /// on), then polls. The diff reply is stamped "1690798021", which is older.
    ///
    /// Verifies:
    /// - The reply really was skipped: stored stamp and id unchanged, no SQL write.
    /// - The flag is still on.
    func testStaleUpsertReplyKeepsUserAttributesUpdatedFlag() {
        let storage = makeStorageHoldingNewerData()
        XCTAssertLessThan(
            Int64(UserEvaluations.mock1Upsert.createdAt)!, Int64(storedEvaluatedAt)!,
            "setup: the reply must be older than the stored data"
        )

        pollAfterAttributeChange(reply: .mock1Upsert, storage: storage)

        XCTAssertEqual(storage.evaluatedAt, storedEvaluatedAt, "stale reply must not be stored")
        XCTAssertEqual(storage.currentEvaluationsId, storedEvaluationsId, "stale reply must not be stored")
        XCTAssertTrue(
            storage.userAttributesState.isUpdated,
            "the re-evaluation for the new attributes was skipped as stale, so the flag must stay on"
        )
    }

    /// Issue: the effect the app would actually feel. After a skipped reply, the next poll
    /// must still ask the server to re-evaluate for the new attributes. If it does not, the
    /// `updateUserAttributes` call is silently lost.
    ///
    /// The two tests above check the flag in storage. This one checks what really goes over
    /// the wire, so it also catches a fix that keeps the flag in storage but somehow does
    /// not send it.
    ///
    /// Setup: one interactor, like a running app. Storage holds data stamped "1690798100".
    /// The app changes attributes, then polls twice. Both replies are older than the stored
    /// data and get skipped; only the requests matter here, not the replies.
    ///
    /// Verifies: both requests carry `userAttributesUpdated: true`. The first proves the
    /// setup; the second is the real check.
    func testNextPollAfterStaleReplyStillSendsUserAttributesUpdated() {
        let storage = makeStorageHoldingNewerData()
        var sent: [Bool] = []
        let interactor = makeInteractor(
            api: makeApi(replies: [.mock1ForceUpdate, .mock1ForceUpdate], sentFlags: { sent.append($0) }),
            storage: storage
        )

        interactor.setUserAttributesUpdated()
        poll(interactor)
        poll(interactor)

        XCTAssertEqual(sent.first, true, "setup: the first poll must carry the flag")
        XCTAssertEqual(
            sent, [true, true],
            "the first reply was skipped as stale, so the next poll must still ask the server to re-evaluate"
        )
    }

    /// Control: the normal case must keep working. When the reply is newer and gets saved,
    /// the server has delivered the re-evaluation, so clearing the flag is correct.
    ///
    /// Without this test, "never clear the flag" would pass the three tests above. The flag
    /// would then stay on forever, and every poll would ask for a full re-evaluation.
    ///
    /// Setup: storage holds data stamped "1690798000". The app changes attributes, then
    /// polls. The reply is stamped "1690798021", which is newer. The SQL mock accepts
    /// writes here.
    ///
    /// Verifies:
    /// - The reply was saved: the stored stamp and id now come from the reply.
    /// - The flag is off.
    func testLandedReplyClearsUserAttributesUpdatedFlag() {
        let storage = EvaluationStorageImpl(
            userId: User.mock1.id,
            evaluationDao: MockEvaluationSQLDao(
                getHandler: { _ in [] },
                startTransactionHandler: { block in try block() }
            ),
            evaluationMemCacheDao: EvaluationMemCacheDao(),
            evaluationUserDefaultsDao: makeUserDefsDao(evaluatedAt: UserEvaluations.mock1.createdAt)
        )
        XCTAssertGreaterThan(
            Int64(UserEvaluations.mock1ForceUpdate.createdAt)!, Int64(UserEvaluations.mock1.createdAt)!,
            "setup: the reply must be newer than the stored data"
        )

        pollAfterAttributeChange(reply: .mock1ForceUpdate, storage: storage)

        XCTAssertEqual(storage.evaluatedAt, UserEvaluations.mock1ForceUpdate.createdAt, "newer reply must be stored")
        XCTAssertEqual(storage.currentEvaluationsId, replyEvaluationsId, "newer reply must be stored")
        XCTAssertFalse(storage.userAttributesState.isUpdated, "the reply was stored, so the flag must be cleared")
    }
}
