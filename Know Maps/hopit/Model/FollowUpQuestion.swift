import Foundation

class FollowUpQuestion: Codable {
    let id: Int
    let content: String

    enum CodingKeys: String, CodingKey {
        case id
        case content
    }

    init(id: Int, content: String) {
        self.id = id
        self.content = content
    }

    // From JSON
    static func fromJson(_ json: [String: Any]) -> FollowUpQuestion? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let followUpQuestion = try? JSONDecoder().decode(FollowUpQuestion.self, from: jsonData) else {
            return nil
        }
        return followUpQuestion
    }

    // To JSON
    func toJson() -> [String: Any]? {
        guard let jsonData = try? JSONEncoder().encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            return nil
        }
        return jsonDict
    }
}
