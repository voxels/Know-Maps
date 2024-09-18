//
//  AssistiveChatHostMessagesDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation

public protocol AssistiveChatHostMessagesDelegate : AnyObject {
    func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID, intent: AssistiveChatHost.Intent?) async throws
    func didTap(placeChatResult:ChatResult) async throws
    func didTap(chatResult:ChatResult, selectedPlaceSearchResponse:PlaceSearchResponse?, selectedPlaceSearchDetails:PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?, intent:AssistiveChatHost.Intent) async
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool) async throws
    func didUpdateQuery(with parameters:AssistiveChatHostQueryParameters) async throws
    func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID) async throws
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters)
}
