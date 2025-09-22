import Foundation

class UserProfile: Codable {
    let id: Int?
    let userSub: String?
    let name: String?
    let email: String?
    let username: String?
    let following: Bool?
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userSub
        case name
        case email
        case username
        case following
        case profilePicture
    }

    init(id: Int? = nil,
         userSub: String? = nil,
         name: String? = nil,
         email: String? = nil,
         username: String? = nil,
         following: Bool? = nil,
         profilePicture: String? = nil) {
        self.id = id
        self.userSub = userSub
        self.name = name
        self.email = email
        self.username = username
        self.following = following
        self.profilePicture = profilePicture
    }

    // From JSON
    static func fromJson(_ json: [String: Any]) -> UserProfile? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let userProfile = try? JSONDecoder().decode(UserProfile.self, from: jsonData) else {
            return nil
        }
        return userProfile
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

