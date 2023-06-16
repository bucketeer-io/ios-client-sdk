import XCTest
@testable import Bucketeer

final class EventDaoTests: XCTestCase {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("event_test.db")
    var path: String { url.path }

    override func setUp() async throws {
        try await super.setUp()
        let db = try SQLite(path: path, logger: nil)

        let eventTable = SQLite.Table(entity: EventEntity())
        let eventSql = eventTable.sqlToCreate()
        try db.exec(query: eventSql)
    }

    override func tearDown() async throws {
        try FileManager.default.removeItem(at: url)

        try await super.tearDown()
    }

    func testAddEventGoal() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EventDaoImpl(db: db)

        try dao.add(event: .mockGoal1)

        let sql = "SELECT id, data FROM Events"
        let statement = try db.prepareStatement(sql: sql)
        let decoder = JSONDecoder()

        // Mock1
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.string(at: 0), "goal_event1")
        XCTAssertEqual(try decoder.decode(Event.self, from: statement.data(at: 1)), Event.mockGoal1)

        // End
        XCTAssertFalse(try statement.step())

        try statement.reset()
        try statement.finalize()
    }

    func testAddEventEvaluation() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EventDaoImpl(db: db)

        try dao.add(event: .mockEvaluation1)

        let sql = "SELECT id, data FROM Events"
        let statement = try db.prepareStatement(sql: sql)
        let decoder = JSONDecoder()

        // Mock1
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.string(at: 0), "evaluation_event1")
        XCTAssertEqual(try decoder.decode(Event.self, from: statement.data(at: 1)), Event.mockEvaluation1)

        // End
        XCTAssertFalse(try statement.step())

        try statement.reset()
        try statement.finalize()
    }

    func testAddEventMetrics() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EventDaoImpl(db: db)

        try dao.add(event: .mockMetricsResponseLatency1)

        let sql = "SELECT id, data FROM Events"
        let statement = try db.prepareStatement(sql: sql)
        let decoder = JSONDecoder()

        // Mock1
        XCTAssertTrue(try statement.step())
        XCTAssertEqual(statement.string(at: 0), "metrics_event1")
        XCTAssertEqual(try decoder.decode(Event.self, from: statement.data(at: 1)), Event.mockMetricsResponseLatency1)

        // End
        XCTAssertFalse(try statement.step())

        try statement.reset()
        try statement.finalize()
    }

    func testAddEvents() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EventDaoImpl(db: db)

        try dao.add(events: [.mockGoal1, .mockEvaluation1, .mockMetricsResponseLatency1, .mockEvaluation2])

        let events = try dao.getEvents()
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0], Event.mockGoal1)
        XCTAssertEqual(events[1], Event.mockEvaluation1)
        XCTAssertEqual(events[2], Event.mockMetricsResponseLatency1)
        XCTAssertEqual(events[3], Event.mockEvaluation2)
    }

    func testDeleteAll() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EventDaoImpl(db: db)
        let target: [Event] = [.mockGoal1, .mockEvaluation1, .mockMetricsResponseLatency1, .mockEvaluation2]
        try dao.add(events: target)

        let ids = target.map(\.id)
        try dao.delete(ids: ids)

        let events = try dao.getEvents()
        XCTAssertEqual(events.count, 0)
    }

    func testDeleteSomeItems() throws {
        let db = try SQLite(path: path, logger: nil)
        let dao = EventDaoImpl(db: db)
        let target: [Event] = [.mockGoal1, .mockEvaluation1, .mockMetricsResponseLatency1, .mockEvaluation2]
        try dao.add(events: target)

        let ids = [Event.mockEvaluation1.id, Event.mockMetricsResponseLatency1.id]
        try dao.delete(ids: ids)

        let events = try dao.getEvents()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0], Event.mockGoal1)
        XCTAssertEqual(events[1], Event.mockEvaluation2)
    }
}
