//
//  AssistiveChatHostMessagesDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import Segment

public protocol AssistiveChatHostMessagesDelegate : AnyObject {
    func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHostService.Intent?, cacheManager:CacheManager) async throws
    func didTap(placeChatResult:ChatResult, cacheManager:CacheManager) async throws
    func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?,
                selectedDestinationChatResultID:UUID?, intent:AssistiveChatHostService.Intent, cacheManager:CacheManager) async
    func didTap(locationChatResult: LocationResult, cacheManager:CacheManager) async throws
    func didTap(categoricalResult:CategoryResult, chatResult:ChatResult?, selectedDestinationChatResultID:UUID, cacheManager:CacheManager) async
    func didTap(chatResult: ChatResult, selectedDestinationChatResultID:UUID?, cacheManager:CacheManager) async
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, cacheManager:CacheManager) async throws
    
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters)
}

