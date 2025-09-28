import Foundation

struct AddressComponent: Codable {
    let longText: String
    let shortText: String
    let types: [String]
    let languageCode: String

    enum CodingKeys: String, CodingKey {
        case longText = "longText"
        case shortText = "shortText"
        case types = "types"
        case languageCode = "languageCode"
    }
}

struct AuthorAttribution: Codable {
    let displayName: String
    let uri: String
    let photoUri: String

    enum CodingKeys: String, CodingKey {
        case displayName = "displayName"
        case uri = "uri"
        case photoUri = "photoUri"
    }
}

struct Photo: Codable {
    let name: String
    let widthPx: Int
    let heightPx: Int
    let authorAttributions: [AuthorAttribution]

    enum CodingKeys: String, CodingKey {
        case name = "name"
        case widthPx = "widthPx"
        case heightPx = "heightPx"
        case authorAttributions = "authorAttributions"
    }
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case latitude = "latitude"
        case longitude = "longitude"
    }
}

struct LatLng: Codable {
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case latitude = "latitude"
        case longitude = "longitude"
    }
}

struct DisplayName: Codable {
    let text: String
    let languageCode: String

    enum CodingKeys: String, CodingKey {
        case text = "text"
        case languageCode = "languageCode"
    }
}

struct PointOfInterest: Codable {
    let name: String
    let types: [String]
    let formattedAddress: String
    let addressComponents: [AddressComponent]
    let location: Location
    let displayName: DisplayName
    let photos: [Photo]?

    enum CodingKeys: String, CodingKey {
        case name = "name"
        case types = "types"
        case formattedAddress = "formattedAddress"
        case addressComponents = "addressComponents"
        case location = "location"
        case displayName = "displayName"
        case photos = "photos"
    }
}
