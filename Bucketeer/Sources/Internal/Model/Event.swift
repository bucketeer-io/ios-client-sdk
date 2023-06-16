import Foundation

struct Event: Codable, Hashable {
    let id: String
    let event: EventData
    let type: EventType
    // note: environment_namespace is not used in client SDK

    init(id: String, event: EventData, type: EventType) {
        self.id = id
        self.event = event
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case id
        case event
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(EventType.self, forKey: .type)
        switch self.type {
        case .goal:
            let data = try container.decode(EventData.Goal.self, forKey: .event)
            self.event = .goal(data)
        case .evaluation:
            let data = try container.decode(EventData.Evaluation.self, forKey: .event)
            self.event = .evaluation(data)
        case .metrics:
            let data = try container.decode(EventData.Metrics.self, forKey: .event)
            self.event = .metrics(data)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        switch self.event {
        case .goal(let eventData):
            try container.encode(eventData, forKey: .event)
        case .evaluation(let eventData):
            try container.encode(eventData, forKey: .event)
        case .metrics(let eventData):
            try container.encode(eventData, forKey: .event)
        }
    }
}

extension Event {
    func isMetricEvent() -> Bool {
        if case .metrics = self.event {
            return true
        }
        return false
    }
}
