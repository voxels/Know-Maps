import Foundation

class PodcastLike: Codable {
    let userProfile: UserProfile?
    //let createdAt: Date?
    //let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userProfile
        //case createdAt
        //case updatedAt
    }

    init(userProfile: UserProfile? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.userProfile = userProfile
       // self.createdAt = createdAt
       // self.updatedAt = updatedAt
    }

    // From JSON
    static func fromJson(_ json: [String: Any]) -> PodcastLike? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let podcastLike = try? JSONDecoder().decode(PodcastLike.self, from: jsonData) else {
            return nil
        }
        return podcastLike
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
