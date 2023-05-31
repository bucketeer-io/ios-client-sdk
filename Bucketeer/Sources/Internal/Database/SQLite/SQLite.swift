import Foundation
import SQLite3

final class SQLite {
    let path: String
    let pointer: OpaquePointer
    let logger: Logger?

    init(path: String, logger: Logger?) throws {
        self.path = path
        self.logger = logger

        sqlite3_shutdown()
        sqlite3_initialize()

        var _pointer: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &_pointer, flags, nil)
        if result != SQLITE_OK {
            guard let pointer = _pointer else {
                throw Error.unknown
            }
            throw Error.failedToOpen(.init(pointer: pointer, result: result))
        }
        guard let pointer = _pointer else {
            throw Error.unknown
        }
        self.pointer = pointer
    }

    deinit {
        sqlite3_close(pointer)
    }
}

extension SQLite {
    func prepareStatement(sql: String) throws -> Statement {
        var _pointer: OpaquePointer?
        let result = sqlite3_prepare_v2(pointer, sql, -1, &_pointer, nil)
        guard result == SQLITE_OK,
            let pointer = _pointer else {
            throw Error.failedToPrepare(.init(pointer: pointer, result: result))
        }
        return .init(pointer: pointer)
    }

    func exec(query: String) throws {
        let result = sqlite3_exec(pointer, query, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw Error.failedToExecute(.init(pointer: pointer, result: result))
        }
    }
}

extension SQLite {
    var userVersion: Int32 {
          get {
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
          set {
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

extension SQLite {
    func select<Entity: SQLiteEntity>(_ entity: Entity, conditions: [Condition]) throws -> [Entity.Model] {
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

    func insert<Entity: SQLiteEntity>(_ entities: [Entity]) throws {
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

    func delete<Entity: SQLiteEntity>(_ entity: Entity, condition: Condition) throws {
        let table = Table(entity: entity)
        let sql = table.sqlToDelete(condition: condition)
        let statement = try prepareStatement(sql: sql)
        try statement.step()
        try statement.reset()
        try statement.finalize()
    }
}
