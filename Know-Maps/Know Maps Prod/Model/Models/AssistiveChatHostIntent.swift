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

    public init<T: Sendable>(_ value: T) {
        self.box = value
    }
}

@MainActor
@Observable
public final class AssistiveChatHostIntent : @MainActor Equatable, Sendable {
    public let uuid = UUID()
    public let caption:String
    public let intent:AssistiveChatHostService.Intent
    public var selectedPlaceSearchResponse:PlaceSearchResponse?
    public var selectedPlaceSearchDetails:PlaceDetailsResponse?
    public let placeSearchResponses:[PlaceSearchResponse]
    public let selectedDestinationLocation:LocationResult
    public var placeDetailsResponses:[PlaceDetailsResponse]?
    public var recommendedPlaceSearchResponses:[RecommendedPlaceSearchResponse]?
    public var relatedPlaceSearchResponses:[RecommendedPlaceSearchResponse]?
    public let queryParameters: [String: AnyHashableSendable]?
    
    // MARK: - Foundation Models Enhancement
    /// Optional enriched intent from Foundation Models classifier
    /// Contains extracted categories, tastes, price range, etc.
    public let enrichedIntent: UnifiedSearchIntent?
    
    public init(caption: String, intent: AssistiveChatHostService.Intent, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, placeSearchResponses: [PlaceSearchResponse], selectedDestinationLocation:LocationResult, placeDetailsResponses:[PlaceDetailsResponse]?, recommendedPlaceSearchResponses:[RecommendedPlaceSearchResponse]? = nil, relatedPlaceSearchResponses:[RecommendedPlaceSearchResponse]? = nil, queryParameters: [String: AnyHashableSendable]?, enrichedIntent: UnifiedSearchIntent? = nil) {
        self.caption = caption
        self.intent = intent
        self.selectedPlaceSearchResponse = selectedPlaceSearchResponse
        self.selectedPlaceSearchDetails = selectedPlaceSearchDetails
        self.placeSearchResponses = placeSearchResponses
        self.selectedDestinationLocation = selectedDestinationLocation
        self.placeDetailsResponses = placeDetailsResponses
        self.recommendedPlaceSearchResponses = recommendedPlaceSearchResponses
        self.relatedPlaceSearchResponses = relatedPlaceSearchResponses
        self.queryParameters = queryParameters
        self.enrichedIntent = enrichedIntent
    }
    
    public static func == (lhs: AssistiveChatHostIntent, rhs: AssistiveChatHostIntent) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

