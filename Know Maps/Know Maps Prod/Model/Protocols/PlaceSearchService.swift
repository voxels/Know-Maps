//
//  PlaceSearchService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

public protocol PlaceSearchService {
    var assistiveHostDelegate: AssistiveChatHost { get }
    var placeSearchSession: PlaceSearchSession { get }
    var personalizedSearchSession: PersonalizedSearchSession { get }
    var analyticsManager:AnalyticsService { get }
    var lastFetchedTastePage: Int { get }
    func retrieveFsqUser() async throws
    func autocompleteTastes(lastIntent: AssistiveChatHostIntent, currentTasteResults:[CategoryResult]) async throws -> [CategoryResult]
    func refreshTastes(page: Int, currentTasteResults:[CategoryResult]) async throws -> [CategoryResult]
    func detailIntent(intent: AssistiveChatHostIntent) async throws
    func placeSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async ->PlaceSearchRequest
    func recommendedPlaceSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async -> RecommendedPlaceSearchRequest
}

