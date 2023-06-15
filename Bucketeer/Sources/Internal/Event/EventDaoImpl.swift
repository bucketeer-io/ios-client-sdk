import Foundation

final class EventDaoImpl: EventDao {
    private let db: SQLite

    init(db: SQLite) {
        self.db = db
    }
    func add(event: Event) throws {
        try add(events: [event])
    }

    func add(events: [Event]) throws {
        let entities = try events
            .map { try EventEntity(model: $0) }
        try db.insert(entities)
    }

    func getEvents() throws -> [Event] {
        try db.select(EventEntity(), conditions: [])
    }

    func delete(ids: [String]) throws {
        try db.delete(EventEntity(), condition: .in(column: "id", values: ids))
    }
}

private extension Event {
    var eventHash: Int {
        return self.event.hashValue
    }
}
