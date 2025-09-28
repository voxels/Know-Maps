import Foundation

// Define the PoisResponse struct
struct PoisResponse: Codable {
    let places: [PointOfInterest]
    
    enum CodingKeys: String, CodingKey {
        case places = "places"
    }
}

