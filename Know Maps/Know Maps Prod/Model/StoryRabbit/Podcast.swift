import Foundation

class Podcast: Codable {
    let id: Int
    let title: String
    let transcript: String?
    let childPodcasts: [Podcast]?
    let comments: [Comment]?
    let parentPodcast: Podcast?
    let followUps: [FollowUpQuestion]?
    let likes: [PodcastLike]?
    //let createdAt: Date?
    //let updatedAt: Date?
    let persona: Persona?
    let address: String?
    let audioUrl: String?
    let shareId: String?
    let message: String?
    let audioLength: Double?
    let hasLiked: Bool?
    let latitude: Double?
    let longitude: Double?
    let userProfile: UserProfile?
    let commentCount: Int?
    let likeCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case transcript
        case childPodcasts
        case comments
        case parentPodcast
        case followUps
        case likes
        //case createdAt
        //case updatedAt
        case persona
        case address
        case audioUrl
        case shareId
        case message
        case audioLength
        case hasLiked
        case latitude
        case longitude
        case userProfile
        case commentCount
        case likeCount
    }

    init(id: Int,
         title: String,
         transcript: String? = nil,
         childPodcasts: [Podcast]? = nil,
         comments: [Comment]? = nil,
         parentPodcast: Podcast? = nil,
         followUps: [FollowUpQuestion]? = nil,
         likes: [PodcastLike]? = nil,
         //createdAt: Date? = nil,
         //updatedAt: Date? = nil,
         persona: Persona? = nil,
         address: String? = nil,
         audioUrl: String? = nil,
         shareId: String? = nil,
         message: String? = nil,
         audioLength: Double? = nil,
         hasLiked: Bool? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         userProfile: UserProfile? = nil,
         commentCount: Int? = nil,
         likeCount: Int? = nil) {
        self.id = id
        self.title = title
        self.transcript = transcript
        self.childPodcasts = childPodcasts
        self.comments = comments
        self.parentPodcast = parentPodcast
        self.followUps = followUps
        self.likes = likes
        //self.createdAt = createdAt
        //self.updatedAt = updatedAt
        self.persona = persona
        self.address = address
        self.audioUrl = audioUrl
        self.shareId = shareId
        self.message = message
        self.audioLength = audioLength
        self.hasLiked = hasLiked
        self.latitude = latitude
        self.longitude = longitude
        self.userProfile = userProfile
        self.commentCount = commentCount
        self.likeCount = likeCount
    }

    func hasChild() -> Bool {
        return childPodcasts != nil && !(childPodcasts?.isEmpty ?? true)
    }

    func isShared() -> Bool {
        return shareId != nil
    }

 
}
