//
//  ChatResult.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import SwiftUI

public struct ChatResult : Identifiable, Equatable, Hashable {
    public static func == (lhs: ChatResult, rhs: ChatResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id = UUID()
    let title:String
    let placeResponse:PlaceSearchResponse?
    private(set) var placeDetailsResponse:PlaceDetailsResponse?
    
    mutating func replaceDetails(response:PlaceDetailsResponse) {
        placeDetailsResponse = response
    }
}
