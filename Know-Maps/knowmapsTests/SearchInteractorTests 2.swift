//
//  SearchInteractorTests.swift
//  knowmapsTests
//
//  Created for SOLID Refactor validation.
//

import XCTest
import CoreLocation
@testable import Know_Maps

@MainActor
final class SearchInteractorTests: XCTestCase {
    var sut: SearchInteractor!
    var mockPlaceSearchService: MockPlaceSearchService!
    var mockAssistiveHost: MockAssistiveChatHost!
    var mockAnalytics: MockAnalyticsService!
    var mockValidator: MockInputValidationServiceV2!
    var mockCache: MockCacheManager!
    
    override func setUp() {
        super.setUp()
        mockAssistiveHost = MockAssistiveChatHost()
        mockPlaceSearchService = MockPlaceSearchService(assistiveHost: mockAssistiveHost)
        mockAnalytics = MockAnalyticsService()
        mockValidator = MockInputValidationServiceV2()
        mockCache = MockCacheManager(analyticsManager: mockAnalytics)
        
        sut = SearchInteractor(
            placeSearchService: mockPlaceSearchService,
            assistiveHostDelegate: mockAssistiveHost,
            analyticsManager: mockAnalytics,
            inputValidator: mockValidator,
            cacheManager: mockCache
        )
    }
    
    override func tearDown() {
        sut = nil
        mockPlaceSearchService = nil
        mockAssistiveHost = nil
        mockAnalytics = nil
        mockCache = nil
        super.tearDown()
    }
    
    func testPerformSearch_ReturnsResults() async throws {
        // Arrange
        let location = LocationResult(locationName: "San Francisco", location: CLLocation(latitude: 37.7749, longitude: -122.4194))
        let intent = sut.buildIntent(
            caption: "coffee",
            intentType: .Search,
            queryParameters: [:],
            selectedDestination: location,
            enrichedIntent: nil
        )
        
        // Act
        let result = try await sut.performSearch(for: intent)
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertTrue(mockAnalytics.trackedEvents.contains("recommendedSearch.parsed") || mockAnalytics.trackedEvents.contains("placeSearch"))
    }
    
    func testPerformAutocomplete_ReturnsResults() async throws {
        let location = LocationResult(locationName: "San Francisco", location: CLLocation(latitude: 37.7749, longitude: -122.4194))
        let intent = sut.buildIntent(caption: "caf", intentType: .Search, queryParameters: nil, selectedDestination: location, enrichedIntent: nil)
        
        let results = try await sut.performAutocomplete(caption: "caf", intent: intent)
        
        XCTAssertNotNil(results)
    }

    // MARK: - Edge Cases

    func testPerformSearch_EmptyInput_HandlesGracefully() async throws {
        let location = LocationResult(locationName: "Nowhere", location: CLLocation())
        let intent = sut.buildIntent(caption: "", intentType: .Search, queryParameters: nil, selectedDestination: location, enrichedIntent: nil)
        
        let result = try await sut.performSearch(for: intent)
        XCTAssertNotNil(result)
        // Depending on mock behavior, might fulfill with empty or default
    }

    func testCreateIntent_WithEnrichedIntent_PopulatesCorrectly() {
        let location = LocationResult(locationName: "LA", location: CLLocation(latitude: 34.05, longitude: -118.24))
        let enriched = UnifiedSearchIntent(searchType: .place, rawQuery: "tacos")
        
        let intent = sut.buildIntent(caption: "tacos", intentType: .Search, queryParameters: nil, selectedDestination: location, enrichedIntent: enriched)
        
        XCTAssertEqual(intent.request.enrichedIntent?.rawQuery, "tacos")
        XCTAssertEqual(intent.selectedDestinationLocation.locationName, "LA")
    }

    func testBuildRelatedResults_EmptyResponses_ReturnsEmpty() async throws {
        let location = LocationResult(locationName: "Test", location: CLLocation())
        let intent = sut.buildIntent(caption: "test", intentType: .Search, queryParameters: nil, selectedDestination: location, enrichedIntent: nil)
        
        // Ensure strictly empty
        intent.fulfillment.related = []
        
        let related = try await sut.buildRelatedResults(intent: intent)
        XCTAssertTrue(related.isEmpty)
    }
    
    func testBuildRelatedResults_WithData_ReturnsChatResults() async throws {
         let location = LocationResult(locationName: "Test", location: CLLocation())
         let intent = sut.buildIntent(caption: "test", intentType: .Search, queryParameters: nil, selectedDestination: location, enrichedIntent: nil)
         
        let mockResponse = PlaceSearchResponse(fsqID: "123", name: "Related Place", categories: [], latitude: 0, longitude: 0, address: "123 St", addressExtended: "", country: "", dma: "", formattedAddress: "", locality: "", postCode: "", region: "", chains: [], link: "", childIDs: [], parentIDs: [])
         intent.fulfillment.related = [mockResponse]
         
         let related = try await sut.buildRelatedResults(intent: intent)
         XCTAssertEqual(related.count, 1)
         XCTAssertEqual(related.first?.title, "Related Place")
         XCTAssertEqual(related.first?.identity, "Related Place")
    }

    func testPrefetchInitialDetails_InvalidCount_ReturnsEmpty() async throws {
        let location = LocationResult(locationName: "Test", location: CLLocation())
        let intent = sut.buildIntent(caption: "test", intentType: .Search, queryParameters: nil, selectedDestination: location, enrichedIntent: nil)
        
        // No places
        let results = try await sut.prefetchInitialDetailsIfNeeded(intent: intent, initialCount: 5)
        XCTAssertTrue(results.isEmpty)
    }
}
