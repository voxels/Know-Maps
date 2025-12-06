//
//  TestFixtures.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
import CoreLocation
@testable import Know_Maps_Prod

@MainActor
struct TestFixtures {
    
    // MARK: - Location Fixtures
    
    static func makeLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194
    ) -> CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    static func makeLocationResult(
        name: String = "Test Location",
        latitude: Double = 37.7749,
        longitude: Double = -122.4194
    ) -> LocationResult {
        return LocationResult(
            locationName: name,
            location: makeLocation(latitude: latitude, longitude: longitude)
        )
    }
    
    // MARK: - ChatResult Fixtures
    
    static func makeChatResult(
        index: Int = 0,
        identity: String = "test-identity",
        title: String = "Test Place",
        list: String = "test-list",
        icon: String = "📍",
        rating: Int = 3,
        section: PersonalizedSearchSection = .food,
        placeResponse: PlaceSearchResponse? = nil,
        recommendedPlaceResponse: RecommendedPlaceSearchResponse? = nil
    ) -> ChatResult {
        return ChatResult(
            index: index,
            identity: identity,
            title: title,
            list: list,
            icon: icon,
            rating: rating,
            section: section,
            placeResponse: placeResponse,
            recommendedPlaceResponse: recommendedPlaceResponse
        )
    }
    
    static func makePlaceSearchResponse(
        fsqID: String = "test-fsq-id",
        name: String = "Test Restaurant",
        latitude: Double = 37.7749,
        longitude: Double = -122.4194
    ) -> PlaceSearchResponse {
        return PlaceSearchResponse(
            fsqID: fsqID,
            name: name,
            location: makeLocation(latitude: latitude, longitude: longitude)
        )
    }
    
    static func makeRecommendedPlaceSearchResponse(
        fsqID: String = "test-rec-id",
        name: String = "Recommended Restaurant"
    ) -> RecommendedPlaceSearchResponse {
        return RecommendedPlaceSearchResponse(
            fsqID: fsqID,
            name: name
        )
    }
    
    // MARK: - CategoryResult Fixtures
    
    static func makeCategoryResult(
        identity: String = "test-category",
        parentCategory: String = "Test Category",
        list: String = "test-list",
        icon: String = "🏭",
        rating: Int = 2,
        section: PersonalizedSearchSection = .business,
        categoricalChatResults: [ChatResult] = []
    ) -> CategoryResult {
        return CategoryResult(
            identity: identity,
            parentCategory: parentCategory,
            list: list,
            icon: icon,
            rating: rating,
            section: section,
            categoricalChatResults: categoricalChatResults
        )
    }
    
    static func makeIndustryCategoryResult(
        identity: String = "restaurants",
        title: String = "Restaurants"
    ) -> CategoryResult {
        let chatResults = [
            makeChatResult(index: 0, identity: "\(identity)-item", title: title, section: .food)
        ]
        return makeCategoryResult(
            identity: identity,
            parentCategory: title,
            section: .food,
            categoricalChatResults: chatResults
        )
    }
    
    static func makeTasteCategoryResult(
        identity: String = "romantic",
        title: String = "Romantic"
    ) -> CategoryResult {
        let chatResults = [
            makeChatResult(index: 0, identity: "\(identity)-taste", title: title, section: .tastes)
        ]
        return makeCategoryResult(
            identity: identity,
            parentCategory: title,
            section: .tastes,
            categoricalChatResults: chatResults
        )
    }
    
    // MARK: - Intent Fixtures
    
    static func makeAssistiveChatHostIntent(
        caption: String = "test query",
        intent: AssistiveChatHostService.Intent = .Search,
        selectedPlaceSearchResponse: PlaceSearchResponse? = nil,
        selectedPlaceSearchDetails: PlaceDetailsResponse? = nil,
        placeSearchResponses: [PlaceSearchResponse] = [],
        selectedDestinationLocation: LocationResult? = nil,
        placeDetailsResponses: [PlaceDetailsResponse]? = nil,
        recommendedPlaceSearchResponses: [RecommendedPlaceSearchResponse]? = nil,
        relatedPlaceSearchResponses: [PlaceSearchResponse]? = nil,
        queryParameters: [String: Any]? = nil
    ) -> AssistiveChatHostIntent {
        let location = selectedDestinationLocation ?? makeLocationResult()
        return AssistiveChatHostIntent(
            caption: caption,
            intent: intent,
            selectedPlaceSearchResponse: selectedPlaceSearchResponse,
            selectedPlaceSearchDetails: selectedPlaceSearchDetails,
            placeSearchResponses: placeSearchResponses,
            selectedDestinationLocation: location,
            placeDetailsResponses: placeDetailsResponses,
            recommendedPlaceSearchResponses: recommendedPlaceSearchResponses,
            relatedPlaceSearchResponses: relatedPlaceSearchResponses,
            queryParameters: queryParameters ?? [:]
        )
    }
    
    // MARK: - RecommendationData Fixtures
    
    static func makeRecommendationData(
        identity: String = "test-recommendation",
        rating: Int = 3
    ) -> RecommendationData {
        return RecommendationData(identity: identity, parentCategory: "Test", rating: rating)
    }
    
    // MARK: - Service Fixtures

    static func makeInputValidationService(
        maxQueryLength: Int = 200
    ) -> DefaultInputValidationServiceV2 {
        return DefaultInputValidationServiceV2(maxQueryLength: maxQueryLength)
    }

    static func makeMockInputValidationService(
        mockSanitizedResult: String = "",
        mockJoinedResult: String = "",
        mockValidationResult: Bool = true
    ) -> MockInputValidationServiceV2 {
        let mock = MockInputValidationServiceV2()
        mock.mockSanitizedResult = mockSanitizedResult
        mock.mockJoinedResult = mockJoinedResult
        mock.mockValidationResult = mockValidationResult
        return mock
    }

    static func makeResultIndexService() -> DefaultResultIndexServiceV2 {
        return DefaultResultIndexServiceV2()
    }

    static func makeMockResultIndexService(
        mockFilteredPlaceResults: [ChatResult] = [],
        mockPlaceChatResultForID: ChatResult? = nil,
        mockPlaceChatResultWithFsqID: ChatResult? = nil
    ) -> MockResultIndexServiceV2 {
        let mock = MockResultIndexServiceV2()
        mock.mockFilteredPlaceResults = mockFilteredPlaceResults
        mock.mockPlaceChatResultForID = mockPlaceChatResultForID
        mock.mockPlaceChatResultWithFsqID = mockPlaceChatResultWithFsqID
        return mock
    }

    // MARK: - Mock Setup Helpers

    static func makeModelController(
        cacheManager: CacheManager? = nil,
        analyticsService: AnalyticsService? = nil,
        locationService: LocationService? = nil
    ) -> DefaultModelController {
        let analytics = analyticsService ?? MockAnalyticsService()
        let mockCloudCacheService = MockCloudCacheService(analyticsManager: analytics)
        let cache = cacheManager ?? MockCacheManager(cloudCacheService: mockCloudCacheService)

        return DefaultModelController(cacheManager: cache)
    }
}

// MARK: - Mock CloudCacheService

@MainActor
final class MockCloudCacheService: CloudCacheService, @unchecked Sendable {
    var analyticsManager: AnalyticsService
    var hasFsqAccess: Bool = true
    
    init(analyticsManager: AnalyticsService) {
        self.analyticsManager = analyticsManager
    }
}
