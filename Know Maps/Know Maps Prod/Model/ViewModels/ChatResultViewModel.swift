//
//  ChatResultViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation
import Segment

enum ChatResultViewModelError: Error {
    case missingLastIntent
    case missingSelectedPlaceSearchResponse
    case missingSelectedPlaceDetailsResponse
    case noAutocompleteResultsFound
    case missingCurrentLocation
    case missingSelectedDestinationLocationChatResult
    case retryTimeout
}

// MARK: - ChatResultViewModel

final class ChatResultViewModel: ObservableObject, AssistiveChatHostMessagesDelegate {
    public var modelController: ModelController
    
    public init(modelController: ModelController) {
        self.modelController = modelController
        self.modelController.assistiveHostDelegate.messagesDelegate = self
    }
    
    // MARK: - Model Building and Query Handling
    
    public func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHostService.Intent? = nil, cacheManager:CacheManager) async throws {
        
        let checkCaption = caption
        
        let destinationChatResultID = selectedDestinationChatResultID
        
        let checkIntent:AssistiveChatHostService.Intent = intent ?? modelController.assistiveHostDelegate.determineIntent(for: checkCaption, override: nil)
        let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption)
        if let lastIntent = modelController.assistiveHostDelegate.queryIntentParameters?.queryIntents.last, lastIntent.caption == caption {
            let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: destinationChatResultID, placeDetailsResponses:lastIntent.placeDetailsResponses,recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, queryParameters: queryParameters)
            
            modelController.assistiveHostDelegate.updateLastIntentParameters(intent:newIntent)
        } else {
            let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID:destinationChatResultID, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent)
        }
        try await modelController.assistiveHostDelegate.receiveMessage(caption: checkCaption, isLocalParticipant:true, cacheManager: cacheManager)
        
    }
    
    public func didTapMarker(with fsqId:String?) async throws {
        guard let fsqId = fsqId else {
            return
        }
        
        if let placeChatResult = modelController.placeChatResult(for:fsqId) {
            await MainActor.run {
                modelController.selectedPlaceChatResult = placeChatResult.id
            }
        }
    }
    
    public func didTap(placeChatResult: ChatResult, cacheManager:CacheManager) async throws {
        guard let lastIntent = modelController.assistiveHostDelegate.queryIntentParameters?.queryIntents.last, lastIntent.placeSearchResponses.count > 0 else {
            return
        }
        
        await MainActor.run {
            modelController.isFetchingResults = true
        }
        
        if modelController.selectedDestinationLocationChatResult == nil {
            await MainActor.run {
                modelController.selectedDestinationLocationChatResult = lastIntent.selectedDestinationLocationID
            }
        }
        
        try await modelController.updateLastIntentParameter(for: placeChatResult, selectedDestinationChatResultID:modelController.selectedDestinationLocationChatResult, cacheManager: cacheManager)
        
        await MainActor.run {
            modelController.isFetchingResults = false
        }
    }
    
    public func didTap(locationChatResult: LocationResult, cacheManager:CacheManager) async throws {
        let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: locationChatResult.locationName)
        
        if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult {
            let newIntent = AssistiveChatHostIntent(caption: locationChatResult.locationName, intent:.Location, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent)
        } else {
            modelController.selectedDestinationLocationChatResult = locationChatResult.id
            let newIntent = AssistiveChatHostIntent(caption: locationChatResult.locationName, intent:.Location, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: locationChatResult.id, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent)
        }
        
        try await modelController.assistiveHostDelegate.receiveMessage(caption: locationChatResult.locationName, isLocalParticipant:true, cacheManager: cacheManager)
    }
    
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?,
                       selectedDestinationChatResultID:UUID?, intent:AssistiveChatHostService.Intent = .Search, cacheManager:CacheManager) async {
        do {
            await MainActor.run {
                modelController.isFetchingResults = true
            }
            
            let caption = chatResult.title
            
            let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption)
            
            let placeSearchResponses = chatResult.placeResponse != nil ? [chatResult.placeResponse!] : [PlaceSearchResponse]()
            let destinationLocationChatResult = selectedDestinationChatResultID
            
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: selectedPlaceSearchResponse, selectedPlaceSearchDetails: selectedPlaceSearchDetails, placeSearchResponses: placeSearchResponses, selectedDestinationLocationID: destinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent)
            try await modelController.assistiveHostDelegate.receiveMessage(caption: chatResult.title, isLocalParticipant: true, cacheManager: cacheManager)
            
            await MainActor.run {
                modelController.isFetchingResults = false
            }
        } catch {
            await MainActor.run {
                modelController.isFetchingResults = false
            }
            
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    
    public func didTap(categoricalResult:CategoryResult, chatResult:ChatResult?, selectedDestinationChatResultID:UUID, cacheManager:CacheManager) async {
        if let chatResult = chatResult {
            await didTap(chatResult: chatResult, selectedDestinationChatResultID: selectedDestinationChatResultID, cacheManager: cacheManager)
        }
    }
    
    public func didTap(chatResult: ChatResult, selectedDestinationChatResultID:UUID?, cacheManager:CacheManager) async {
        print("Did tap result:\(chatResult.title) for place:\(chatResult.placeResponse?.fsqID ?? "")")
        var intent = AssistiveChatHostService.Intent.Search
        if let placeResponse = chatResult.placeResponse, !placeResponse.fsqID.isEmpty, placeResponse.name.isEmpty {
            intent = .Place
        }
        
        await didTap(chatResult: chatResult, selectedPlaceSearchResponse: chatResult.placeResponse, selectedPlaceSearchDetails:chatResult.placeDetailsResponse, selectedRecommendedPlaceSearchResponse: chatResult.recommendedPlaceResponse, selectedDestinationChatResultID:selectedDestinationChatResultID, intent:intent, cacheManager: cacheManager )
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, cacheManager:CacheManager) async throws {
        try await modelController.addReceivedMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant, cacheManager: cacheManager)
    }
    
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) {
        modelController.updateQueryParametersHistory(with: parameters)
    }
}

/*
 extension ChatResultViewModel : AssistiveChatHostStreamResponseDelegate {
 public func didReceiveStreamingResult(with string: String, for result: ChatResult, promptTokens: Int, completionTokens: Int) async {
 await didReceiveStreamingResult(with: string, for: result)
 if promptTokens > 0 || completionTokens > 0 {
 analytics?.track(name: "usingGeneratedGPTDescription", properties: ["promptTokens":promptTokens, "completionTokens":completionTokens])
 }
 }
 
 @MainActor
 public func willReceiveStreamingResult(for chatResultID: ChatResult.ID) async {
 fetchingPlaceID = chatResultID
 isFetchingPlaceDescription = true
 }
 
 public func didFinishStreamingResult() async {
 if let fetchingPlaceID = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: fetchingPlaceID), let fsqid = placeChatResult.placeDetailsResponse?.fsqID, let description = placeChatResult.placeDetailsResponse?.description {
 assistiveHostDelegate?.cloudCache.storeGeneratedDescription(for: fsqid, description:description)
 }
 
 await MainActor.run {
 fetchingPlaceID = nil
 isFetchingPlaceDescription = false
 }
 }
 
 private func didReceiveStreamingResult(with string: String, for result: ChatResult) async {
 let candidates = placeResults.filter { checkResult in
 return checkResult.placeResponse?.fsqID != nil && checkResult.placeResponse?.fsqID == result.placeResponse?.fsqID
 }
 
 guard let firstCandidate = candidates.first else {
 return
 }
 
 var selectedId:ChatResult.ID = firstCandidate.id
 
 if let placeDetailsResponse = firstCandidate.placeDetailsResponse {
 let newDetailsResponse = PlaceDetailsResponse(searchResponse: placeDetailsResponse.searchResponse, photoResponses: placeDetailsResponse.photoResponses, tipsResponses: placeDetailsResponse.tipsResponses, description: (placeDetailsResponse.description ?? "").appending(string), tel: placeDetailsResponse.tel, fax: placeDetailsResponse.fax, email: placeDetailsResponse.email, website: placeDetailsResponse.website, socialMedia: placeDetailsResponse.socialMedia, verified: placeDetailsResponse.verified, hours: placeDetailsResponse.hours, openNow: placeDetailsResponse.openNow, hoursPopular:placeDetailsResponse.hoursPopular, rating: placeDetailsResponse.rating, stats: placeDetailsResponse.stats, popularity: placeDetailsResponse.popularity, price: placeDetailsResponse.price, menu: placeDetailsResponse.menu, dateClosed: placeDetailsResponse.dateClosed, tastes: placeDetailsResponse.tastes, features: placeDetailsResponse.features)
 
 var newPlaceResults = [ChatResult]()
 let fsqID = newDetailsResponse.fsqID
 for placeResult in placeResults {
 if placeResult.placeResponse?.fsqID == fsqID {
 let newPlaceResult = ChatResult(title: placeResult.title, list:placeResult.list, section:placeResult.section, placeResponse: placeResult.placeResponse, recommendedPlaceResponse: nil, placeDetailsResponse: newDetailsResponse)
 newPlaceResults.append(newPlaceResult)
 selectedId = newPlaceResult.id
 } else {
 newPlaceResults.append(placeResult)
 }
 }
 
 await MainActor.run {
 placeResults = newPlaceResults
 selectedPlaceChatResult = selectedId
 selectedPlaceChatResult = selectedId
 }
 }
 }
 }
 
 */
