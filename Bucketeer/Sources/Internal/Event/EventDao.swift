import Foundation

protocol EventDao {
    func add(event: Event) throws
    func add(events: [Event]) throws
    func getEvents() throws -> [Event]

    /// Delete rows by ID
    func delete(ids: [String]) throws
}
