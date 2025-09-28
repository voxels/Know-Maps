import Foundation

struct CreateMultiPOIPodcastRequest: Codable {
    let pois: [PointOfInterest]
    let personaId: Int
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case pois
        case personaId
        case latitude
        case longitude
    }
}
