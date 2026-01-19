import Foundation

struct RegisterEventsRequestBody: Codable {
    internal init(events: [Event] = [],
                  sdkVersion: String,
                  sourceId: SourceID
    ) {
        self.events = events
        self.sdkVersion = sdkVersion
        self.sourceId = sourceId
    }

    let events: [Event]
    let sdkVersion: String
    let sourceId: SourceID
}
