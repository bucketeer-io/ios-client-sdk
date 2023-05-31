import Foundation
@testable import Bucketeer

final class MockEvaluationDao: EvaluationDao {

    typealias PutHandler = ((String, [Evaluation]) throws -> Void)
    typealias GetHandler = (String) throws -> [Evaluation]
    typealias DeleteAllAndInsertHandler = (String, [Evaluation]) throws -> Void

    let putHandler: PutHandler?
    let getHandler: GetHandler?
    let deleteAllAndInsertHandler: DeleteAllAndInsertHandler?

    init(putHandler: PutHandler? = nil,
         getHandler: GetHandler? = nil,
         deleteAllAndInsertHandler: DeleteAllAndInsertHandler? = nil) {

        self.putHandler = putHandler
        self.getHandler = getHandler
        self.deleteAllAndInsertHandler = deleteAllAndInsertHandler
    }

    func put(userId: String, evaluations: [Evaluation]) throws {
        try putHandler?(userId, evaluations)
    }

    func get(userId: String) throws -> [Evaluation] {
        return try getHandler?(userId) ?? []
    }

    func deleteAllAndInsert(userId: String, evaluations: [Evaluation]) throws {
        try deleteAllAndInsertHandler?(userId, evaluations)
    }
}
