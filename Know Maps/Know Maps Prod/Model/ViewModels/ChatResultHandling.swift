//
//  ChatResultHandling.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

protocol ChatResultHandling {
    // Place Chat Result Handling
    func placeChatResult(for id: ChatResult.ID) -> ChatResult?
    func placeChatResult(for fsqID: String) -> ChatResult?
    func resetPlaceModel()
    func didTap(placeChatResult: ChatResult) async throws
    
    // Location Result Handling
    func locationChatResult(for id: LocationResult.ID) -> LocationResult?
    func locationChatResult(with title: String) async -> LocationResult
    func didTap(locationChatResult: LocationResult) async throws
    
    // Category Result Handling
    func didTap(chatResult: ChatResult, selectedDestinationChatResultID:UUID?) async
    func didTap(categoricalResult:CategoryResult, chatResult:ChatResult?, selectedDestinationChatResultID:UUID) async
    
    // Search Intent Handling
    func searchIntent(intent: AssistiveChatHostIntent, location: CLLocation?) async throws
    func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent, location: CLLocation) async throws
    
    // Query Handling
    func refreshModel(query: String, queryIntents: [AssistiveChatHostIntent]?) async throws
    func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHost.Intent?) async throws 
    
    // Session Management
    func refreshSessions() async throws
    
    // Message Handling
    func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws    
}
