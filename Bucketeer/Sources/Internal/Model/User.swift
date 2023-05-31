import Foundation

struct User: Codable, Hashable {
    let id: String
    var data: [String: String]
    // note: tagged_data is not used in client SDK
}
