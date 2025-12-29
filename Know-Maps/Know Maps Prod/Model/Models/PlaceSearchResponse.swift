//
//  PlaceSearchResponse.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import Foundation

public struct PlaceSearchResponse: Codable, Equatable, Hashable, Sendable {
    let uuid: String = UUID().uuidString
    let fsqID:String
    let name:String
    let categories:[String]
    let latitude:Double
    let longitude:Double
    let address:String
    let addressExtended:String
    let country:String
    let dma:String
    let formattedAddress:String
    let locality:String
    let postCode:String
    let region:String
    let chains:[String]
    let link:String
    let childIDs:[String]
    let parentIDs:[String]
    let tastes:[String]?
    
    let neighborhood:String?
    let city:String
    let state:String

    public init(fsqID: String, name: String, categories: [String], latitude: Double, longitude: Double, address: String, addressExtended: String, country: String, dma: String, formattedAddress: String, locality: String, postCode: String, region: String, chains: [String], link: String, childIDs: [String], parentIDs: [String], tastes: [String]? = nil, neighborhood: String? = nil, city: String = "", state: String = "") {
        self.fsqID = fsqID
        self.name = name
        self.categories = categories
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.addressExtended = addressExtended
        self.country = country
        self.dma = dma
        self.formattedAddress = formattedAddress
        self.locality = locality
        self.postCode = postCode
        self.region = region
        self.chains = chains
        self.link = link
        self.childIDs = childIDs
        self.parentIDs = parentIDs
        self.tastes = tastes
        self.neighborhood = neighborhood
        self.city = city
        self.state = state
    }
}
