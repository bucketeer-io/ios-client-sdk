import Foundation

struct RegisterEventsRequestBody: Codable {
    let events: [Event]
    let sdkVersion: String
    let sourceId: SourceID
}
