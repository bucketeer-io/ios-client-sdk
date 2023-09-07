import Foundation
import SQLite3

final class SQLite {
    let path: String
    let pointer: OpaquePointer
    let logger: Logger?
    // access SQLite on one serial queue to prevent `database is locked` or database corrupt
    private static let dbQueue = DispatchQueue(label: "io.bucketeer.SQLite")

    init(path: String, logger: Logger?) throws {
        self.path = path
        self.logger = logger
        pointer = try Self.dbQueue.sync {
            var _pointer: OpaquePointer?
            let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
            let result = sqlite3_open_v2(path, &_pointer, flags, nil)
            if result != SQLITE_OK {
                guard let dbConnection = _pointer else {
                    throw Error.unknown
                }
                throw Error.failedToOpen(.init(errorMessage: dbConnection.readErrorMessage(), result: result))
            }
            guard let dbConnection = _pointer else {
                throw Error.unknown
            }
            return dbConnection
        }
    }

    deinit {
        let dbConnection = pointer
        Self.dbQueue.async {
            sqlite3_close_v2(dbConnection)
        }
    }
}

extension SQLite {
    func prepareStatement(sql: String) throws -> Statement {
        var _pointer: OpaquePointer?
        let result = sqlite3_prepare_v2(pointer, sql, -1, &_pointer, nil)
        guard result == SQLITE_OK,
              let pointer = _pointer else {
            throw Error.failedToPrepare(.init(errorMessage: pointer.readErrorMessage(), result: result))
        }
        return .init(pointer: pointer)
    }

    func exec(query: String) throws {
        try Self.dbQueue.sync {
            let result = sqlite3_exec(pointer, query, nil, nil, nil)
            guard result == SQLITE_OK else {
                throw Error.failedToExecute(.init(errorMessage: pointer.readErrorMessage(), result: result))
            }
        }
    }
}

extension SQLite {
    var userVersion: Int32 {
        get {
            Self.dbQueue.sync {
                do {
                    let statement = try prepareStatement(sql: "PRAGMA user_version")
                    try statement.step()
                    let userVersion = statement.int(at: 0)
                    try statement.reset()
                    try statement.finalize()
                    return userVersion
                } catch let error {
                    logger?.error(error)
                    return 0
                }
            }
        }
        set {
            Self.dbQueue.sync {
                do {
                    let statement = try prepareStatement(sql: "PRAGMA user_version = \(newValue)")
                    repeat {} while try statement.step()
                    try statement.reset()
                    try statement.finalize()
                } catch let error {
                    logger?.error(error)
                }
            }
        }
    }
}

extension SQLite {
    func select<Entity: SQLiteEntity>(_ entity: Entity, conditions: [Condition]) throws -> [Entity.Model] {
        try Self.dbQueue.sync {
            let table = Table(entity: entity)
            let sql = table.sqlToSelect(conditions: conditions)
            let statement = try prepareStatement(sql: sql)
            var models: [Entity.Model] = []
            while (try statement.step()) {
                do {
                    let model = try Entity.model(from: statement)
                    models.append(model)
                } catch let error {
                    logger?.error(error)
                }
            }
            try statement.reset()
            try statement.finalize()
            return models
        }
    }

    func insert<Entity: SQLiteEntity>(_ entities: [Entity]) throws {
        try Self.dbQueue.sync {
            for entity in entities {
                let table = Table(entity: entity)
                let sql = table.sqlToInsert()
                var statement = try prepareStatement(sql: sql)
                for column in table.columns {
                    statement = try statement.bind(name: column.name, value: column.column.anyValue)
                }
                try statement.step()
                try statement.reset()
                try statement.finalize()
            }
        }
    }

    func delete<Entity: SQLiteEntity>(_ entity: Entity, condition: Condition) throws {
        try Self.dbQueue.sync {
            let table = Table(entity: entity)
            let sql = table.sqlToDelete(condition: condition)
            let statement = try prepareStatement(sql: sql)
            try statement.step()
            try statement.reset()
            try statement.finalize()
        }
    }

    func startTransaction(block: () throws -> Void) throws {
        let beginTransactionQuery = "BEGIN;"
        let result = sqlite3_exec(pointer, beginTransactionQuery, nil, nil, nil)
        guard result == SQLITE_OK else {
            logger?.warn(message:"Failed to start transaction")
            throw Error.failedToExecute(.init(errorMessage: pointer.readErrorMessage(), result: result))
        }

        do {
            try block()
            let commitTransactionQuery = "COMMIT;"
            let commitResult = sqlite3_exec(pointer, commitTransactionQuery, nil, nil, nil)
            guard commitResult == SQLITE_OK else {
                logger?.warn(message:"Failed to commit transaction")
                throw Error.failedToExecute(.init(errorMessage: pointer.readErrorMessage(), result: result))
            }
        } catch {
            try rollback()
            // forward original error caused the rollback to the caller
            throw error
        }
    }

    private func rollback() throws {
        let rollbackQuery = "ROLLBACK;"
        logger?.warn(message:"Transaction rolled back")
        let result = sqlite3_exec(pointer, rollbackQuery, nil, nil, nil)
        guard result == SQLITE_OK else {
            logger?.warn(message:"Failed to rollback transaction")
            throw Error.failedToExecute(.init(errorMessage: pointer.readErrorMessage(), result: result))
        }
    }
}
