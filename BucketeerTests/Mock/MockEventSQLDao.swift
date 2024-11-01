import Foundation
@testable import Bucketeer

final class MockEventSQLDao: EventSQLDao {
    typealias AddEventsHandler = (([Event]) throws -> Void)
    typealias GetEventsHandler = () throws -> [Event]
    typealias DeleteEventsHandler = ([String]) throws -> Void

    let addEventsHandler: AddEventsHandler?
    let getEventsHandler: GetEventsHandler?
    let deleteEventsHandler: DeleteEventsHandler?
    var events: [Event] = []
    private let lock = NSLock()

    init(addEventsHandler: AddEventsHandler? = nil,
         getEventsHandler: GetEventsHandler? = nil,
         deleteEventsHandler: DeleteEventsHandler? = nil) {
        self.addEventsHandler = addEventsHandler
        self.getEventsHandler = getEventsHandler
        self.deleteEventsHandler = deleteEventsHandler
    }

    func add(event: Event) throws {
        try add(events: [event])
    }

    func add(events: [Event]) throws {
        lock.lock()
        defer { lock.unlock() }

        try addEventsHandler?(events)
        self.events.append(contentsOf: events)
    }

    func getEvents() throws -> [Event] {
        return try getEventsHandler?() ?? events
    }

    func delete(ids: [String]) throws {
        lock.lock()
        defer { lock.unlock() }

        try deleteEventsHandler?(ids)
        events.removeAll(where: { ids.contains($0.id) })
    }
}
