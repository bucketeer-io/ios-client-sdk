import Foundation
@testable import Bucketeer

final class MockEvaluationDao: EvaluationDao {
    func startTransaction(block: () throws -> Void) throws {
        try self.startTransactionHandler?(block)
    }

    typealias PutHandler = ((String, [Evaluation]) throws -> Void)
    typealias GetHandler = (String) throws -> [Evaluation]
    typealias DeleteAllHandler = (String) throws -> Void
    typealias DeleteByIdsHandler = ([String]) throws -> Void
    typealias StartTransactionHandler = (TransactionBlock) throws -> Void

    let putHandler: PutHandler?
    let getHandler: GetHandler?
    let deleteAllHandler: DeleteAllHandler?
    let deleteByIdsHanlder: DeleteByIdsHandler?
    let startTransactionHandler: StartTransactionHandler?

    init(putHandler: PutHandler? = nil,
         getHandler: GetHandler? = nil,
         deleteAllHandler: DeleteAllHandler? = nil,
         deleteByIdsHandlder: DeleteByIdsHandler? = nil,
         startTransactionHandler: StartTransactionHandler? = nil) {
        self.putHandler = putHandler
        self.getHandler = getHandler
        self.deleteAllHandler = deleteAllHandler
        self.deleteByIdsHanlder = deleteByIdsHandlder
        self.startTransactionHandler = startTransactionHandler
    }

    func put(userId: String, evaluations: [Evaluation]) throws {
        try putHandler?(userId, evaluations)
    }

    func get(userId: String) throws -> [Evaluation] {
        return try getHandler?(userId) ?? []
    }

    func deleteByIds(_ ids: [String]) throws {
        try deleteByIdsHanlder?(ids)
    }

    func deleteAll(userId: String) throws {
        try deleteAllHandler?(userId)
    }
}
