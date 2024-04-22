import Foundation

struct RegisterEventsRequestBody: Codable {
    internal init(events: [Event] = [],
                  sdkVersion: String = Version.current,
                  sourceId: SourceID = SourceID.ios
    ) {
        self.events = events
        self.sdkVersion = sdkVersion
        self.sourceId = sourceId
    }
    
    let events: [Event]
    let sdkVersion: String
    let sourceId: SourceID
}
