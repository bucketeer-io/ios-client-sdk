import XCTest
@testable import Bucketeer

class SQLiteTests: XCTestCase {

    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.db")
    var path: String {
        url.path
    }

    override func setUp() async throws {
        try await super.setUp()

        let db = try SQLite(path: path, logger: nil)
        let table = SQLite.Table(entity: MockEntity())
        let sql = table.sqlToCreate()
        try db.exec(query: sql)

        let entities = [
            try MockEntity(model: .init(id: "id1", value: 1)),
            try MockEntity(model: .init(id: "id2", value: 2))
        ]
        try db.insert(entities)
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: url)

        try await super.tearDown()
    }

    func testInit() throws {
        let db = try SQLite(path: url.path, logger: nil)
        XCTAssertEqual(db.path, url.path)
        XCTAssertNil(db.logger)
        XCTAssertTrue(FileManager.default.fileExists(atPath: db.path))
    }

    func testUserVersion() throws {
        let logger = MockLogger()
        let db = try SQLite(path: url.path, logger: logger)
        XCTAssertEqual(db.userVersion, 0)
        db.userVersion = 2
        XCTAssertEqual(db.userVersion, 2)
    }

    func testInsert() throws {
        let entities = [
            try MockEntity(model: .init(id: "id100", value: 100)),
            try MockEntity(model: .init(id: "id200", value: 200))
        ]
        let db = try SQLite(path: path, logger: nil)
        try db.insert(entities)
    }

    func testSelect() throws {
        let db = try SQLite(path: path, logger: nil)
        let selected = try db.select(MockEntity(), conditions: [.equal(column: "id", value: "id1")])
        XCTAssertEqual(selected.count, 1)
        guard let entity = selected.first else {
            return
        }
        XCTAssertEqual(entity.id, "id1")
        XCTAssertEqual(entity.value, 1)
    }

    func testDelete() throws {
        let db = try SQLite(path: path, logger: nil)
        try db.delete(MockEntity(), condition: .equal(column: "id", value: "id1"))
    }
}

class SQLiteComponentsTests: XCTestCase {
    func testCondition() {
        let equalCondition = SQLite.Condition.equal(column: "column1", value: "value1")
        XCTAssertEqual(equalCondition.sql, "column1 = \"value1\"")
        let notinCondition = SQLite.Condition.notin(column: "column2", values: ["value1", "value2"])
        XCTAssertEqual(notinCondition.sql, "column2 NOT IN (\"value1\", \"value2\")")
    }

    func testColumn() {
        let column1 = SQLiteColumn<String>(value: "value1", isPrimaryKey: true)
        XCTAssertEqual(column1.value, "value1")
        XCTAssertEqual(column1.isPrimaryKey, true)
        XCTAssertEqual(column1.sql(includesPrimaryKey: true), "TEXT PRIMARY KEY")
        XCTAssertEqual(column1.sql(includesPrimaryKey: false), "TEXT")
        let column2 = SQLiteColumn<Int>(value: 1, isPrimaryKey: false)
        XCTAssertEqual(column2.value, 1)
        XCTAssertEqual(column2.isPrimaryKey, false)
        XCTAssertEqual(column2.sql(includesPrimaryKey: true), "INTEGER")
    }

    func testTable() {
        let table = SQLite.Table<MockEntity>(entity: MockEntity())
        XCTAssertEqual(table.name, "Mock")
        XCTAssertEqual(table.sqlToCreate(), "CREATE TABLE IF NOT EXISTS Mock (id TEXT PRIMARY KEY, value INTEGER, data BLOB);")
        XCTAssertEqual(table.sqlToSelect(conditions: [.equal(column: "id", value: "some_id")]), "SELECT id, value, data FROM Mock WHERE id = \"some_id\";")
        XCTAssertEqual(table.sqlToInsert(), "INSERT OR REPLACE INTO Mock (id, value, data) VALUES (:id, :value, :data);")
        XCTAssertEqual(table.sqlToDelete(condition: .equal(column: "id", value: "some_id")), "DELETE FROM Mock WHERE id = \"some_id\";")
    }

    func testMultiPrimaryKeyTable() {
        let table = SQLite.Table(entity: MockMultiPrimaryKeyEntity())
        XCTAssertEqual(table.name, "Mock")
        XCTAssertEqual(table.sqlToCreate(), "CREATE TABLE IF NOT EXISTS Mock (id TEXT, id2 TEXT, data BLOB PRIMARY KEY(id, id2));")
    }
}

private struct MockEntity: SQLiteEntity {
    struct Model: Codable {
        var id: String = "some_id"
        var value: Int = 100
    }

    static var tableName: String { "Mock" }

    var id = SQLiteColumn<String>(value: "", isPrimaryKey: true)
    var value = SQLiteColumn<Int>(value: 0)
    var data = SQLiteColumn<Data>(value: .init())

    static func model(from statement: SQLite.Statement) throws -> Model {
        let data = statement.data(at: 2)
        return try JSONDecoder().decode(Model.self, from: data)
    }
}

private struct MockMultiPrimaryKeyEntity: SQLiteEntity {
    struct Model: Codable {
        var id: String = "some_id"
    }

    static var tableName: String { "Mock" }

    var id = SQLiteColumn<String>(value: "", isPrimaryKey: true)
    var id2 = SQLiteColumn<String>(value: "", isPrimaryKey: true)
    var data = SQLiteColumn<Data>(value: .init())

    static func model(from statement: SQLite.Statement) throws -> Model {
        let data = statement.data(at: 2)
        return try JSONDecoder().decode(Model.self, from: data)
    }
}

extension MockEntity {
    init(model: Model) throws {
        self.id.value = model.id
        self.value.value = model.value
        let data = try JSONEncoder().encode(model)
        self.data.value = data
    }
}
