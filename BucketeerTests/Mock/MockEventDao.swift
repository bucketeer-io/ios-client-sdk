import Foundation
@testable import Bucketeer

final class MockEventDao: EventDao {
    typealias AddEventHandler = ((Event) throws -> Void)
    typealias AddEventsHandler = (([Event]) throws -> Void)
    typealias GetEventsHandler = () throws -> [Event]
    typealias DeleteEventsHandler = ([String]) throws -> Void

    let addEventHandler: AddEventHandler?
    let addEventsHandler: AddEventsHandler?
    let getEventsHandler: GetEventsHandler?
    let deleteEventsHandler: DeleteEventsHandler?
    var events: [Event] = []

    init(addEventHandler: AddEventHandler? = nil,
         addEventsHandler: AddEventsHandler? = nil,
         getEventsHandler: GetEventsHandler? = nil,
         deleteEventsHandler: DeleteEventsHandler? = nil) {
        self.addEventHandler = addEventHandler
        self.addEventsHandler = addEventsHandler
        self.getEventsHandler = getEventsHandler
        self.deleteEventsHandler = deleteEventsHandler
    }

    func add(event: Event) throws {
        try addEventHandler?(event)
        events.append(event)
    }

    func add(events: [Event]) throws {
        try addEventsHandler?(events)
        self.events.append(contentsOf: events)
    }

    func getEvents() throws -> [Event] {
        return try getEventsHandler?() ?? events
    }

    func delete(ids: [String]) throws {
        try deleteEventsHandler?(ids)
        events.removeAll(where: { ids.contains($0.id) })
    }
}
