import Foundation

struct RegisterEventsRequestBody: Codable {
    let events: [Event]
    let sdkVersion: String
}
