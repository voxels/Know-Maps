//
//  AssistiveChatHostIntent.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import ConcurrencyExtras

/// A lightweight type-erased wrapper for values that conform to `Sendable`.
/// Use this when you need to store heterogeneous `Sendable` values
/// (e.g., in dictionaries) without exposing concrete types.
public struct AnySendable: Sendable {
    private let box: any Sendable
    public var value: any Sendable { box }

    public init<T: Sendable>(_ value: T) {
        self.box = value
    }
}

@MainActor
@Observable
public final class AssistiveChatHostIntent : @MainActor Equatable, Sendable {
    public let uuid = UUID()
    
    // MARK: - Components
    public let request: IntentRequest
    public let context: IntentContext
    public let fulfillment: IntentFulfillment
    
    // MARK: - Legacy / Convenience Accessors
    // These help minimize the impact on existing code that expects properties directly on the intent.
    public var caption: String { request.caption }
    public var intent: AssistiveChatHostService.Intent { request.intentType }
    public var enrichedIntent: UnifiedSearchIntent? { request.enrichedIntent }
    public var selectedDestinationLocation: LocationResult { context.destination }
    public var queryParameters: [String: AnySendable]? { request.rawParameters }
    
    public var selectedPlaceSearchResponse: PlaceSearchResponse? {
        get { fulfillment.selectedPlace }
        set { fulfillment.selectedPlace = newValue }
    }
    public var selectedPlaceSearchDetails: PlaceDetailsResponse? {
        get { fulfillment.selectedDetails }
        set { fulfillment.selectedDetails = newValue }
    }
    public var places: [PlaceSearchResponse] {
        get { fulfillment.places }
        set { fulfillment.places = newValue }
    }
    public var placeDetailsResponses: [PlaceDetailsResponse] {
        get { fulfillment.detailsList ?? [] }
        set { fulfillment.detailsList = newValue }
    }
    public var relatedPlaceSearchResponses: [PlaceSearchResponse] {
        get { fulfillment.related ?? [] }
        set { fulfillment.related = newValue }
    }
    public var recommendations: [PlaceSearchResponse]? {
        get { fulfillment.recommendations }
        set { fulfillment.recommendations = newValue }
    }
    public var related: [PlaceSearchResponse]? {
        get { fulfillment.related }
        set { fulfillment.related = newValue }
    }
    public var detailsList: [PlaceDetailsResponse]? {
        get { fulfillment.detailsList }
        set { fulfillment.detailsList = newValue }
    }
    
    // MARK: - Initialization
    public init(
        request: IntentRequest,
        context: IntentContext,
        fulfillment: IntentFulfillment = IntentFulfillment()
    ) {
        self.request = request
        self.context = context
        self.fulfillment = fulfillment
    }
    
    /// Migration Initializer: to support existing call sites temporarily or provide a familiar interface.
    public init(
        caption: String,
        intent: AssistiveChatHostService.Intent,
        selectedPlaceSearchResponse: PlaceSearchResponse? = nil,
        selectedPlaceSearchDetails: PlaceDetailsResponse? = nil,
        placeSearchResponses: [PlaceSearchResponse] = [],
        selectedDestinationLocation: LocationResult,
        placeDetailsResponses: [PlaceDetailsResponse]? = nil,
        recommendedPlaceSearchResponses: [PlaceSearchResponse]? = nil,
        relatedPlaceSearchResponses: [PlaceSearchResponse]? = nil,
        queryParameters: [String: Any]? = nil,
        enrichedIntent: UnifiedSearchIntent? = nil
    ) {
        let anyParams = queryParameters?.mapValues { value in
            if let s = value as? AnySendable { return s }
            return AnySendable(value as! Sendable) 
        }
        
        self.request = IntentRequest(
            caption: caption,
            intentType: intent,
            enrichedIntent: enrichedIntent,
            rawParameters: anyParams
        )
        
        self.context = IntentContext(destination: selectedDestinationLocation)
        
        let fulfill = IntentFulfillment()
        fulfill.places = placeSearchResponses
        fulfill.selectedPlace = selectedPlaceSearchResponse
        fulfill.selectedDetails = selectedPlaceSearchDetails
        fulfill.detailsList = placeDetailsResponses
        fulfill.recommendations = recommendedPlaceSearchResponses
        fulfill.related = relatedPlaceSearchResponses
        self.fulfillment = fulfill
    }

    /// Overload for AnySendable parameters
    public init(
        caption: String,
        intent: AssistiveChatHostService.Intent,
        selectedPlaceSearchResponse: PlaceSearchResponse? = nil,
        selectedPlaceSearchDetails: PlaceDetailsResponse? = nil,
        placeSearchResponses: [PlaceSearchResponse] = [],
        selectedDestinationLocation: LocationResult,
        placeDetailsResponses: [PlaceDetailsResponse]? = nil,
        recommendedPlaceSearchResponses: [PlaceSearchResponse]? = nil,
        relatedPlaceSearchResponses: [PlaceSearchResponse]? = nil,
        queryParameters: [String: AnySendable]? = nil,
        enrichedIntent: UnifiedSearchIntent? = nil
    ) {
        self.request = IntentRequest(
            caption: caption,
            intentType: intent,
            enrichedIntent: enrichedIntent,
            rawParameters: queryParameters
        )
        
        self.context = IntentContext(destination: selectedDestinationLocation)
        
        let fulfill = IntentFulfillment()
        fulfill.places = placeSearchResponses
        fulfill.selectedPlace = selectedPlaceSearchResponse
        fulfill.selectedDetails = selectedPlaceSearchDetails
        fulfill.detailsList = placeDetailsResponses
        fulfill.recommendations = recommendedPlaceSearchResponses
        fulfill.related = relatedPlaceSearchResponses
        self.fulfillment = fulfill
    }
    
    public static func == (lhs: AssistiveChatHostIntent, rhs: AssistiveChatHostIntent) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

// MARK: - Supporting Types

public struct IntentRequest: Sendable {
    public let caption: String
    public let intentType: AssistiveChatHostService.Intent
    public let enrichedIntent: UnifiedSearchIntent?
    public let rawParameters: [String: AnySendable]?
    
    public init(caption: String, intentType: AssistiveChatHostService.Intent, enrichedIntent: UnifiedSearchIntent? = nil, rawParameters: [String: AnySendable]? = nil) {
        self.caption = caption
        self.intentType = intentType
        self.enrichedIntent = enrichedIntent
        self.rawParameters = rawParameters
    }
}

public struct IntentContext: Sendable {
    public let destination: LocationResult
    
    public init(destination: LocationResult) {
        self.destination = destination
    }
}

@MainActor
@Observable
public final class IntentFulfillment: Sendable {
    public var places: [PlaceSearchResponse] = []
    public var recommendations: [PlaceSearchResponse]?
    public var related: [PlaceSearchResponse]?
    public var selectedPlace: PlaceSearchResponse?
    public var selectedDetails: PlaceDetailsResponse?
    public var detailsList: [PlaceDetailsResponse]?
    
    nonisolated public init() {}
}

