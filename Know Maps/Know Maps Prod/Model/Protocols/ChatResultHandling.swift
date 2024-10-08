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
    func resetPlaceModel()
    func didTap(placeChatResult: ChatResult) async throws
    
    // Location Result Handling
    func didTap(locationChatResult: LocationResult) async throws
    
    // Category Result Handling
    func didTap(chatResult: ChatResult, selectedDestinationChatResultID:UUID?) async
    func didTap(categoricalResult:CategoryResult, chatResult:ChatResult?, selectedDestinationChatResultID:UUID) async
    
    // Query Handling
    func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHostService.Intent?) async throws
}
