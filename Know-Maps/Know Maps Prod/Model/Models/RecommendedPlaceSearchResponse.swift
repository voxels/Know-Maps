//
//  RecommendedPlaceSearchResponse.swift
//  Know Maps
//

import Foundation

public struct RecommendedPlaceSearchResponse: Codable, Equatable, Hashable, Sendable {
    let uuid: String = UUID().uuidString
    let fsqID:String
    let name:String
    let latitude:Double
    let longitude:Double
    
    public let neighborhood: String?
    public let city: String?
    public let state: String?
    public let country: String?
    public let formattedAddress: String?
    public let tastes: [String]?
    public let photo: String?
    public let photos: [String]?
    public let aspectRatio: Double?
    public let categories: [FSQCategory]?
    public let address: String?
    public let postCode: String?
    
    public init(fsqID: String, name: String, latitude: Double, longitude: Double, neighborhood: String? = nil, city: String? = nil, state: String? = nil, country: String? = nil, formattedAddress: String? = nil, tastes: [String]? = nil, photo: String? = nil, photos: [String]? = nil, aspectRatio: Double? = nil, categories: [FSQCategory]? = nil, address: String? = nil, postCode: String? = nil) {
        self.fsqID = fsqID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.neighborhood = neighborhood
        self.city = city
        self.state = state
        self.country = country
        self.formattedAddress = formattedAddress
        self.tastes = tastes
        self.photo = photo
        self.photos = photos
        self.aspectRatio = aspectRatio
        self.categories = categories
        self.address = address
        self.postCode = postCode
    }
}
