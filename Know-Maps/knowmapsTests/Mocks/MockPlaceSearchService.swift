//
//  MockPlaceSearchService.swift
//  knowmapsTests
//

import Foundation
import CoreLocation
@testable import Know_Maps

public final class MockPlaceSearchSession: PlaceSearchSessionProtocol {
    public func searchLocations(caption: String, locationResult: Know_Maps.LocationResult?) async throws -> [Know_Maps.LocationResult] {
        return []
    }
    
    public var mockSearchResponse: FSQSearchResponse = FSQSearchResponse(results: [])
    public var mockPlace: FSQPlace = FSQPlace(fsq_id: "1", name: "Mock Place", geocodes: nil, location: nil, categories: nil, place_description: nil, tel: nil, fax: nil, email: nil, website: nil, social_media: nil, verified: nil, hours: nil, rating: nil, popularity: nil, price: nil, date_closed: nil, tastes: nil)
    public var mockPhotos: FSQPhotosResponse = []
    public var mockTips: [FSQTip] = []
    public var mockAutocompleteResponse: FSQAutocompleteResponse = FSQAutocompleteResponse(results: [])

    public init() {}
    
    public func query(request: PlaceSearchRequest) async throws -> FSQSearchResponse { mockSearchResponse }
    public func details(for request: PlaceDetailsRequest) async throws -> FSQPlace { mockPlace }
    public func photos(for fsqID: String) async throws -> FSQPhotosResponse { mockPhotos }
    public func tips(for fsqID: String) async throws -> [FSQTip] { mockTips }
    public func autocomplete(caption: String, limit: Int?, locationResult: LocationResult) async throws -> FSQAutocompleteResponse { mockAutocompleteResponse }
}

public final class MockPersonalizedSearchSession: PersonalizedSearchSessionProtocol {
    public var fsqIdentity: String?
    public var fsqAccessToken: String?
    public var mockTastes: FSQTastesResponse = FSQTastesResponse(tastes: [])
    public var mockRecommended: [PlaceSearchResponse] = []
    public var mockRelated: [PlaceSearchResponse] = []

    public init() {}
    
    public func fetchManagedUserIdentity(cacheManager: CacheManager) async throws -> String? { fsqIdentity }
    public func fetchManagedUserAccessToken(cacheManager: CacheManager) async throws -> String { fsqAccessToken ?? "" }
    public func addFoursquareManagedUserIdentity(cacheManager: CacheManager) async throws -> Bool { true }
    public func autocompleteTastes(caption: String, parameters: [String : String]?, cacheManager: CacheManager) async throws -> FSQTastesResponse { mockTastes }
    public func fetchRecommendedVenues(with request: RecommendedPlaceSearchRequest, cacheManager: CacheManager) async throws -> [PlaceSearchResponse] { mockRecommended }
    public func fetchTastes(page: Int, cacheManager: CacheManager) async throws -> FSQTastesResponse { mockTastes }
    public func fetchRelatedVenues(for fsqID: String, cacheManager: CacheManager) async throws -> [PlaceSearchResponse] { mockRelated }
}

public final class MockPlaceSearchService: PlaceSearchService {
    public var assistiveHostDelegate: AssistiveChatHost
    public var placeSearchSession: PlaceSearchSessionProtocol
    public var personalizedSearchSession: PersonalizedSearchSessionProtocol
    public var analyticsManager: AnalyticsService
    public var lastFetchedTastePage: Int = 0
    
    public init(
        assistiveHost: AssistiveChatHost,
        placeSearchSession: PlaceSearchSessionProtocol = MockPlaceSearchSession(),
        personalizedSearchSession: PersonalizedSearchSessionProtocol = MockPersonalizedSearchSession(),
        analyticsManager: AnalyticsService = MockAnalyticsService()
    ) {
        self.assistiveHostDelegate = assistiveHost
        self.placeSearchSession = placeSearchSession
        self.personalizedSearchSession = personalizedSearchSession
        self.analyticsManager = analyticsManager
    }

    public func retrieveFsqUser(cacheManager: CacheManager) async throws {}
    public func autocompleteTastes(lastIntent: AssistiveChatHostIntent, currentTasteResults: [CategoryResult], cacheManager: CacheManager) async throws -> [CategoryResult] { [] }
    public func refreshTastes(page: Int, currentTasteResults: [CategoryResult], cacheManager: CacheManager) async throws -> [CategoryResult] { [] }
    public func detailIntent(intent: AssistiveChatHostIntent, cacheManager: CacheManager) async throws {}
    public func placeSearchRequest(intent: AssistiveChatHostIntent) async -> PlaceSearchRequest { 
        PlaceSearchRequest(query: "", ll: nil, radius: 0, categories: nil, fields: nil, minPrice: 1, maxPrice: 4, openAt: nil, openNow: nil, nearLocation: nil, sort: nil, limit: 0)
    }
    public func recommendedPlaceSearchRequest(intent: AssistiveChatHostIntent) async -> RecommendedPlaceSearchRequest {
        RecommendedPlaceSearchRequest(query: "", ll: nil, radius: 0, categories: "", minPrice: 1, maxPrice: 4, openNow: nil, limit: 0, section: .topPicks, tags: [:])
    }
    public func fetchRelatedPlaces(for fsqID: String, cacheManager: CacheManager) async throws -> [PlaceSearchResponse] { [] }
    
    public func fetchPlaceByID(fsqID: String) async throws -> ChatResult {
        return ChatResult(
            index: 0,
            identity: fsqID,
            title: "Mock Place",
            list: "",
            icon: "",
            rating: 0.0,
            section: .topPicks,
            placeResponse: nil
        )
    }
}
