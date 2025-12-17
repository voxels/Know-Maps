//
//  ChatResult.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import SwiftUI

public struct ChatResult : Identifiable, Equatable, Hashable, Sendable {
    public static func == (lhs: ChatResult, rhs: ChatResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id:String
    private(set) var parentId:String? = nil
    let index:Int
    let identity:String
    let title:String
    let list:String
    let icon:String
    let rating:Double
    let section:PersonalizedSearchSection
    private(set) var placeResponse:PlaceSearchResponse?
    let recommendedPlaceResponse:RecommendedPlaceSearchResponse?
    
    private(set) var placeDetailsResponse:PlaceDetailsResponse?
    
    public init(parentId: String? = nil, index: Int, identity: String, title: String, list: String, icon: String, rating: Double, section: PersonalizedSearchSection, placeResponse: PlaceSearchResponse?, recommendedPlaceResponse: RecommendedPlaceSearchResponse?, placeDetailsResponse: PlaceDetailsResponse? = nil) {
        self.id = identity
        self.parentId = parentId
        self.index = index
        self.identity = identity
        self.title = title
        self.list = list
        self.icon = icon
        self.rating = rating
        self.section = section
        self.placeResponse = placeResponse
        self.recommendedPlaceResponse = recommendedPlaceResponse
        self.placeDetailsResponse = placeDetailsResponse
    }
    
    mutating func attachParentId(_ uuid:String) {
        parentId = uuid
    }
    
    mutating func replace(response:PlaceSearchResponse) {
        placeResponse = response
    }
    
    mutating func replaceDetails(response:PlaceDetailsResponse) {
        placeDetailsResponse = response
    }
}

extension ChatResult {
    func toItemMetadata() -> ItemMetadata? {
        // Try recommended response first
        if let r = recommendedPlaceResponse {
            return ItemMetadata(
                id: r.fsqID,
                title: r.name,
                descriptionText: nil,
                styleTags: r.categories,
                categories: r.categories,
                location: r.formattedAddress,
                price: nil
            )
        }

        // Otherwise fallback to search response
        if let p = placeResponse {
            return ItemMetadata(
                id: p.fsqID,
                title: p.name,
                descriptionText: p.formattedAddress,
                styleTags: p.categories,
                categories: p.categories,
                location: p.formattedAddress,
                price: nil
            )
        }

        return nil
    }
}
