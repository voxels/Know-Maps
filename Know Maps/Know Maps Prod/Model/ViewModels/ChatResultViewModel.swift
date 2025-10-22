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

public final class ChatResultViewModel: AssistiveChatHostMessagesDelegate {
    
    static let shared = ChatResultViewModel()
    
    // MARK: - Model Building and Query Handling
    
    public func didSearch(caption: String, selectedDestinationChatResult: LocationResult, intent: AssistiveChatHostService.Intent? = nil,filters:[String:Any], modelController:ModelController) async throws {

        let checkCaption = caption
        
        // Capture the main-actor isolated delegate once to avoid crossing actor boundaries in autoclosures
        let assistiveHostDelegate = await modelController.assistiveHostDelegate
        
        let checkIntent: AssistiveChatHostService.Intent
        if let providedIntent = intent {
            checkIntent = providedIntent
        } else {
            checkIntent = assistiveHostDelegate.determineIntent(for: checkCaption, override: nil)
        }
        let queryParameters = try await assistiveHostDelegate.defaultParameters(for: caption, filters: filters)
        if let lastIntent = assistiveHostDelegate.queryIntentParameters.queryIntents.last, lastIntent.caption == caption {
            let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocation: lastIntent.selectedDestinationLocation, placeDetailsResponses:lastIntent.placeDetailsResponses,recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, relatedPlaceSearchResponses: lastIntent.relatedPlaceSearchResponses, queryParameters: queryParameters)
            
            await assistiveHostDelegate.updateLastIntentParameters(intent:newIntent, modelController: modelController)
        } else {
            try await modelController.resetPlaceModel()

            let newIntent = await AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocation:modelController.selectedDestinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
        }
        
        try await assistiveHostDelegate.receiveMessage(caption: checkCaption, isLocalParticipant:true, filters: filters, modelController: modelController)
        
    }
    
    public func didTap(placeChatResult: ChatResult, filters:[String:Any],  modelController:  ModelController) async throws {

        let assistiveHostDelegate = await modelController.assistiveHostDelegate

        // If we have a last intent with populated placeSearchResponses, update it as before
        if let lastIntent = assistiveHostDelegate.queryIntentParameters.queryIntents.last, lastIntent.placeSearchResponses.count > 0 {
            try await modelController.updateLastIntentParameter(for: placeChatResult, selectedDestinationChatResult:modelController.selectedDestinationLocationChatResult, filters: filters)
            return
        }

        // Fallback: construct a fresh intent using the tapped result so details can be fetched
        let selectedPlaceSearchResponse = placeChatResult.placeResponse
        let selectedRecommendedPlaceSearchResponse = placeChatResult.recommendedPlaceResponse
        var inferredIntent: AssistiveChatHostService.Intent = .Search
        if selectedPlaceSearchResponse != nil { inferredIntent = .Place }

        await didTap(
            chatResult: placeChatResult,
            selectedPlaceSearchResponse: selectedPlaceSearchResponse,
            selectedPlaceSearchDetails: placeChatResult.placeDetailsResponse,
            selectedRecommendedPlaceSearchResponse: selectedRecommendedPlaceSearchResponse,
            selectedDestinationChatResult: modelController.selectedDestinationLocationChatResult,
            intent: inferredIntent,
            filters: filters,
            modelController: modelController
        )
    }
    
    public func didTap(locationChatResult: LocationResult, modelController: ModelController) async throws {
        let assistiveHostDelegate = await modelController.assistiveHostDelegate

        let queryParameters = try await assistiveHostDelegate.defaultParameters(for: locationChatResult.locationName, filters: [:])
        
        let newIntent = AssistiveChatHostIntent(caption: locationChatResult.locationName, intent:.Location, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocation: locationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
        
        await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
        
        try await assistiveHostDelegate.receiveMessage(caption: locationChatResult.locationName, isLocalParticipant:true,filters:[:], modelController: modelController)
    }
    
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?,
                       selectedDestinationChatResult:LocationResult, intent:AssistiveChatHostService.Intent = .Search,
                       filters:[String:Any],
                    modelController: ModelController) async {
        do {
            let assistiveHostDelegate = await modelController.assistiveHostDelegate

            let caption = chatResult.title
            
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: caption, filters: filters)
            
            let placeSearchResponses = chatResult.placeResponse != nil ? [chatResult.placeResponse!] : [PlaceSearchResponse]()
            
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: selectedPlaceSearchResponse, selectedPlaceSearchDetails: selectedPlaceSearchDetails, placeSearchResponses: placeSearchResponses, selectedDestinationLocation: selectedDestinationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
            try await assistiveHostDelegate.receiveMessage(caption: chatResult.title, isLocalParticipant: true, filters: filters, modelController: modelController)
            
            
        } catch {
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func didTap(chatResult: ChatResult, selectedDestinationChatResult: LocationResult, filters: [String : Any], modelController: any ModelController) async {
        print("Did tap result:\(chatResult.title) for place:\(chatResult.placeResponse?.fsqID ?? "")")
        var intent = AssistiveChatHostService.Intent.Search
        if let placeResponse = chatResult.placeResponse, !placeResponse.fsqID.isEmpty {
            intent = .Place
        }
        
        await didTap(chatResult: chatResult, selectedPlaceSearchResponse: chatResult.placeResponse, selectedPlaceSearchDetails:chatResult.placeDetailsResponse, selectedRecommendedPlaceSearchResponse: chatResult.recommendedPlaceResponse, selectedDestinationChatResult:selectedDestinationChatResult, intent:intent, filters: filters,  modelController: modelController )
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, filters:[String:Any], modelController:ModelController) async throws {
        try await modelController.addReceivedMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant, filters: filters)
    }
    
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters, modelController:ModelController) async {
        await modelController.updateQueryParametersHistory(with: parameters)
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

