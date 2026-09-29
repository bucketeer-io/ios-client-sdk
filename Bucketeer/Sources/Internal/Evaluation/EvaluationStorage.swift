import Foundation

/// Outcome of an `EvaluationStorage` write.
///
/// "Skipped" and "saved" must stay distinguishable: a poll clears the
/// user-attributes-updated flag only when its reply was saved, because a skipped reply may
/// have been the re-evaluation that flag asked for.
enum EvaluationWriteResult: Equatable {
    /// The write was skipped because `evaluatedAt` is strictly older than what is stored.
    /// Nothing changed.
    case skippedStale
    /// The write was saved. `shouldNotify` says whether listeners should hear about it.
    /// This is not change detection: see each write method for when it is `true`.
    case landed(shouldNotify: Bool)
}

protocol EvaluationStorage {
    func getBy(featureId: String) -> Evaluation?
    func get() throws -> [Evaluation]

    /// Deletes everything currently stored and inserts `evaluations` (a full snapshot,
    /// used for `forceUpdate`).
    /// - Returns: `.skippedStale` if `evaluatedAt` is strictly older than what is already
    ///   stored, otherwise `.landed(shouldNotify: true)`. A snapshot that empties the cache
    ///   still returns `.landed(shouldNotify: true)`, and callers must still notify
    ///   listeners in that case.
    @discardableResult func deleteAllAndInsert(
        evaluationId: String,
        evaluations: [Evaluation],
        evaluatedAt: String) throws -> EvaluationWriteResult

    /// Merges `evaluations` into what is stored and removes `archivedFeatureIds`.
    /// - Returns: `.skippedStale` if `evaluatedAt` is strictly older than what is already
    ///   stored. Otherwise `.landed(shouldNotify:)`, with `true` when either
    ///   `evaluations` or `archivedFeatureIds` is nonempty. That means "this patch carried
    ///   content worth notifying about", not that stored values differ: an evaluation
    ///   identical to the stored one, or an archived ID that is not stored, still gives
    ///   `true`.
    @discardableResult func update(
        evaluationId: String,
        evaluations: [Evaluation],
        archivedFeatureIds: [String],
        evaluatedAt: String) throws -> EvaluationWriteResult
    func refreshCache() throws

    var currentEvaluationsId: String { get }
    var featureTag: String { get }
    // expected set evaluatedAt from `deleteAllAndInsert` or `update` only
    var evaluatedAt: String { get }

    // Current version and flag set when `setUserAttributesUpdated()` is called
    var userAttributesState: UserAttributesState { get }

    func clearCurrentEvaluationsId()
    func setFeatureTag(value: String)
    func setUserAttributesUpdated()

    /// Atomically clear the user-attributes-updated flag if the stored version equals `state.version`.
    /// - Parameter state: Snapshot obtained from `userAttributesState` before a network request.
    /// - Returns: `true` if the flag was cleared (stored flag was `true` and versions matched); `false` otherwise.
    /// - Thread-safety: Implementations MUST perform the compare-and-swap under the storage's internal lock.
    /// - Note: `version` is an in-memory, session-only counter; implementations may persist only the
    /// boolean flag (e.g., in `UserDefaults`), but the `version` must be treated as transient.
    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool
}

/// Snapshot representing the current user-attributes update state for the current app session.
///
/// - `version`: Monotonically increasing counter. Incremented each time `setUserAttributesUpdated()`
///   is called to indicate a new update event. This value is kept in memory only and is not
///   persisted across app restarts.
/// - `isUpdated`: `true` if user attributes have been modified since the last evaluation (i.e., a
///   new update event exists); `false` otherwise. Implementations may persist this flag (for
///   example, in `UserDefaults`) to survive restarts.
///
/// Use this struct as an in-memory snapshot to coordinate whether evaluations must be refreshed
/// due to user attribute changes during a single session. It is not intended to be persisted as a
/// whole across app restarts.
///
/// The ephemeral nature of the version counter is intentional. We employ an Optimistic Locking pattern where the integer value does not need to persist across app restarts:
/// - On restart: The persisted `isUpdated` flag is authoritative. If `true`, an immediate sync is triggered, regardless of the version.
/// - During runtime: The `version` acts as a transaction ID to safely handle race conditions where user attributes change while a background fetch is in progress.
/// - Correctness: The update flag is only cleared via a compare-and-swap check (`currentVersion == capturedVersion`).
/// If the user modifies attributes during a fetch, the `version` increments, the check fails, and the flag remains `true` to schedule a subsequent sync.
struct UserAttributesState {
    let version: Int
    let isUpdated: Bool
}
