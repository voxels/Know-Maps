//
//  AssistiveChatHostIntent.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation

public class AssistiveChatHostIntent : Equatable {
    public let uuid = UUID()
    public let caption:String
    public let intent:AssistiveChatHost.Intent
    public var selectedPlaceSearchResponse:PlaceSearchResponse?
    public var selectedPlaceSearchDetails:PlaceDetailsResponse?
    public var placeSearchResponses:[PlaceSearchResponse]
    public var selectedDestinationLocationID:LocationResult.ID
    
    public var placeDetailsResponses:[PlaceDetailsResponse]?
    public let queryParameters:[String:Any]?
    
    public init(caption: String, intent: AssistiveChatHost.Intent, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, placeSearchResponses: [PlaceSearchResponse],selectedDestinationLocationID:LocationResult.ID, placeDetailsResponses:[PlaceDetailsResponse]?, queryParameters: [String : Any]?) {
        self.caption = caption
        self.intent = intent
        self.selectedPlaceSearchResponse = selectedPlaceSearchResponse
        self.selectedPlaceSearchDetails = selectedPlaceSearchDetails
        self.placeSearchResponses = placeSearchResponses
        self.selectedDestinationLocationID = selectedDestinationLocationID
        self.placeDetailsResponses = placeDetailsResponses
        self.queryParameters = queryParameters
    }
    
    public static func == (lhs: AssistiveChatHostIntent, rhs: AssistiveChatHostIntent) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
