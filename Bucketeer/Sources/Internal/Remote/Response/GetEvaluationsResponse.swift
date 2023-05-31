import Foundation

struct GetEvaluationsResponse {
    let evaluations: UserEvaluations
    let userEvaluationsId: String
    var seconds: TimeInterval = 0
    var sizeByte: Int64 = 0
    var featureTag: String = ""
}

extension GetEvaluationsResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case evaluations
        case userEvaluationsId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.evaluations = try container.decode(UserEvaluations.self, forKey: .evaluations)
        self.userEvaluationsId = try container.decode(String.self, forKey: .userEvaluationsId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.evaluations, forKey: .evaluations)
        try container.encode(self.userEvaluationsId, forKey: .userEvaluationsId)
    }
}
