//
//  PlaceSearchService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

public protocol PlaceSearchService: Sendable {
    var assistiveHostDelegate: AssistiveChatHost { get }
    var placeSearchSession: PlaceSearchSession { get }
    var personalizedSearchSession: PersonalizedSearchSession { get }
    var analyticsManager:AnalyticsService { get }
    var lastFetchedTastePage: Int { get }
    func retrieveFsqUser(cacheManager:CacheManager) async throws
    func autocompleteTastes(lastIntent: AssistiveChatHostIntent, currentTasteResults:[CategoryResult], cacheManager:CacheManager) async throws -> [CategoryResult]
    func refreshTastes(page: Int, currentTasteResults:[CategoryResult], cacheManager:CacheManager) async throws -> [CategoryResult]
    func detailIntent(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws
    func placeSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async ->PlaceSearchRequest
    func recommendedPlaceSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async -> RecommendedPlaceSearchRequest
}

