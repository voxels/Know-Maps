//
//  MockPlaceSearchService.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
import CoreLocation
@testable import Know_Maps

final class MockPlaceSearchService: PlaceSearchService, @unchecked Sendable {
    
    var assistiveHostDelegate: AssistiveChatHost
    var placeSearchSession: PlaceSearchSession
    var personalizedSearchSession: PersonalizedSearchSession
    var analyticsManager: AnalyticsService
    var lastFetchedTastePage: Int = 0
    
    // Configurable responses
    var mockTastes: [CategoryResult] = []
    var shouldThrowError: Bool = false
    var errorToThrow: Error = NSError(domain: "MockError", code: 1, userInfo: nil)
    
    // Track method calls
    var retrieveFsqUserCalled: Bool = false
    var autocompleteTastesCalled: Bool = false
    var refreshTastesCalled: Bool = false
    var detailIntentCalled: Bool = false
    var placeSearchRequestCalled: Bool = false
    var recommendedPlaceSearchRequestCalled: Bool = false
    
    init(
        assistiveHostDelegate: AssistiveChatHost,
        placeSearchSession: PlaceSearchSession,
        personalizedSearchSession: PersonalizedSearchSession,
        analyticsManager: AnalyticsService
    ) {
        self.assistiveHostDelegate = assistiveHostDelegate
        self.placeSearchSession = placeSearchSession
        self.personalizedSearchSession = personalizedSearchSession
        self.analyticsManager = analyticsManager
    }
    
    func retrieveFsqUser(cacheManager: CacheManager) async throws {
        retrieveFsqUserCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func autocompleteTastes(lastIntent: AssistiveChatHostIntent, currentTasteResults: [CategoryResult], cacheManager: CacheManager) async throws -> [CategoryResult] {
        autocompleteTastesCalled = true
        if shouldThrowError { throw errorToThrow }
        return mockTastes
    }
    
    func refreshTastes(page: Int, currentTasteResults: [CategoryResult], cacheManager: CacheManager) async throws -> [CategoryResult] {
        refreshTastesCalled = true
        lastFetchedTastePage = page
        if shouldThrowError { throw errorToThrow }
        return mockTastes
    }
    
    func detailIntent(intent: AssistiveChatHostIntent, cacheManager: CacheManager) async throws {
        detailIntentCalled = true
        if shouldThrowError { throw errorToThrow }
    }
    
    func placeSearchRequest(intent: AssistiveChatHostIntent) async -> PlaceSearchRequest {
        placeSearchRequestCalled = true
        // Provide required parameters with simple test defaults
        return PlaceSearchRequest(
            query: "",
            ll: nil,
            categories: nil,
            fields: "",
            openAt: nil,
            openNow: nil,
            nearLocation: nil,
            sort: nil
        )
    }
    
    func recommendedPlaceSearchRequest(intent: AssistiveChatHostIntent) async -> RecommendedPlaceSearchRequest {
        recommendedPlaceSearchRequestCalled = true
        // Provide required parameters with simple test defaults
        return RecommendedPlaceSearchRequest(
            query: "",
            ll: nil,
            categories:"",
            openNow: nil,
            section:.topPicks,
            tags: [:]
        )
    }
}

