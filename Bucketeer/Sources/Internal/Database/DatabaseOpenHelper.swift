import Foundation

final class DatabaseOpenHelper {
    static var directory: FileManager.SearchPathDirectory {
        #if os(tvOS)
        return .cachesDirectory
        #else
        return .libraryDirectory
        #endif
    }

    static func createDatabase(logger: Logger?) throws -> SQLite {
        let directoryURL = try FileManager.default
            .url(for: directory, in: .userDomainMask, appropriateFor: nil, create: true)

        let dbURL = directoryURL.appendingPathComponent(Constant.DB.FILE_NAME)
        let db = try SQLite(path: dbURL.path, logger: logger)

        let oldVersion = db.userVersion
        let newVersion = Constant.DB.VERSION
        if oldVersion != newVersion {
            try onUpgrate(db: db, oldVersion: oldVersion, newVersion: newVersion)
        }
        return db
    }

    static func onUpgrate(db: SQLite, oldVersion: Int32, newVersion: Int32) throws {
        if oldVersion < 2 {
            try Migration1to2(db: db).migration()
        }
    }
}
