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
    
    public let id = UUID()
    private(set) var parentId:UUID? = nil
    let index:Int
    let identity:String
    let title:String
    let list:String
    let icon:String
    let rating:Double
    let section:PersonalizedSearchSection
    let placeResponse:PlaceSearchResponse?
    let recommendedPlaceResponse:RecommendedPlaceSearchResponse?
    
    private(set) var placeDetailsResponse:PlaceDetailsResponse?
    
    mutating func attachParentId(uuid:UUID) {
        parentId = uuid
    }
    
    mutating func replaceDetails(response:PlaceDetailsResponse) {
        placeDetailsResponse = response
    }
}
