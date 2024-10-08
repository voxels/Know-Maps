//
//  AssistiveChatHostMessagesDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import Segment

public protocol AssistiveChatHostMessagesDelegate : AnyObject {
    func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHostService.Intent?) async throws
    func didTap(placeChatResult:ChatResult) async throws
    func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?,
                       selectedDestinationChatResultID:UUID?, intent:AssistiveChatHostService.Intent) async
    
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool) async throws
    
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters)
}

