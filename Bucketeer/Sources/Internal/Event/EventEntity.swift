import Foundation

struct EventEntity: SQLiteEntity {
    static var tableName: String {
        return "Events"
    }

    typealias Model = Event

    var id = SQLiteColumn<String>(value: "", isPrimaryKey: true)
    var data = SQLiteColumn<Data>(value: .init())

    static func model(from statement: SQLite.Statement) throws -> Event {
        let data = statement.data(at: 1)
        return try JSONDecoder().decode(Event.self, from: data)
    }
}

extension EventEntity {
    init(model: Model) throws {
        self.id.value = model.id
        let data = try JSONEncoder().encode(model)
        self.data.value = data
    }
}
