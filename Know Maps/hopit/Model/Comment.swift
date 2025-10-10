import Foundation

class Comment: Codable {
    let id: Int
    let podcastId: Int?
    let userProfileId: Int?
    let parentCommentId: Int?
    //let createdAt: Date?
    //let updatedAt: Date?
    let message: String
    let userProfile: UserProfile?
    let replies: [Comment]?

    enum CodingKeys: String, CodingKey {
        case id
        case podcastId
        case userProfileId
        case parentCommentId
        //case createdAt
        //case updatedAt
        case message
        case userProfile
        case replies
    }

    init(id: Int,
         podcastId: Int? = nil,
         userProfileId: Int? = nil,
         parentCommentId: Int? = nil,
         //createdAt: Date? = nil,
         //updatedAt: Date? = nil,
         message: String,
         userProfile: UserProfile? = nil,
         replies: [Comment]? = nil) {
        self.id = id
        self.podcastId = podcastId
        self.userProfileId = userProfileId
        self.parentCommentId = parentCommentId
        //self.createdAt = createdAt
        //self.updatedAt = updatedAt
        self.message = message
        self.userProfile = userProfile
        self.replies = replies
    }

    // From JSON
    static func fromJson(_ json: [String: Any]) -> Comment? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let comment = try? JSONDecoder().decode(Comment.self, from: jsonData) else {
            return nil
        }
        return comment
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
