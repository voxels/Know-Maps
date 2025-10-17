//
//  AssistiveChatHostMessagesDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import Segment

public protocol AssistiveChatHostMessagesDelegate : AnyObject, Sendable {
    func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHostService.Intent?, filters:[String:Any], cacheManager:CacheManager, modelController:ModelController) async throws
    func didTap(placeChatResult:ChatResult, filters:[String:Any], cacheManager:CacheManager, modelController: ModelController) async throws
    func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?,
                selectedDestinationChatResultID:String?, intent:AssistiveChatHostService.Intent, filters:[String:Any], cacheManager:CacheManager, modelController: ModelController) async
    func didTap(locationChatResult: LocationResult, cacheManager:CacheManager, modelController: ModelController) async throws
    func didTap(chatResult: ChatResult, selectedDestinationChatResultID:String?, filters:[String:Any], cacheManager:CacheManager, modelController: ModelController) async
    func undoLastIntent(filters:[String:Any], cacheManager:CacheManager, modelController:ModelController) async throws
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, filters:[String:Any], cacheManager:CacheManager, modelController:ModelController) async throws
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters, modelController:ModelController) async
}

