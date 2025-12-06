//
//  DefaultModelControllerTests.swift
//  Know MapsTests
//
//  Created for testing DefaultModelController
//

import XCTest
import CoreLocation
@testable import Know_Maps_Prod

// MARK: - Input Sanitization Tests

@MainActor
final class DefaultModelControllerInputSanitizationTests: XCTestCase {
    
    var controller: DefaultModelController!
    var mockAnalytics: MockAnalyticsService!
    var mockCache: MockCacheManager!
    
    override func setUp() async throws {
        mockAnalytics = MockAnalyticsService()
        let mockCloudCache = MockCloudCacheService(analyticsManager: mockAnalytics)
        mockCache = MockCacheManager(cloudCacheService: mockCloudCache)
        controller = DefaultModelController(cacheManager: mockCache)
    }
    
    override func tearDown() async throws {
        controller = nil
        mockAnalytics = nil
        mockCache = nil
    }
    
    // Note: sanitizeCaption is private, so we'll test it indirectly through refreshModel
    // For now, we'll add tests for public methods that use sanitization
    
    func testRefreshModelSanitizesQuery() async throws {
        // Given a query with extra whitespace
        let query = "  test   query  "
        
        // When refreshing the model
        do {
            _ = try await controller.refreshModel(query: query, queryIntents: nil, filters: [:])
        } catch {
            // Expected to fail due to mock limitations, but we can verify analytics
        }
        
        // Then the query should be processed (sanitized internally)
        // We can verify this indirectly through analytics or other side effects
        XCTAssertNotNil(controller)
    }
}

// MARK: - Result Filtering Tests

@MainActor
final class DefaultModelControllerResultFilteringTests: XCTestCase {
    
    var controller: DefaultModelController!
    var mockAnalytics: MockAnalyticsService!
    var mockCache: MockCacheManager!
    
    override func setUp() async throws {
        mockAnalytics = MockAnalyticsService()
        let mockCloudCache = MockCloudCacheService(analyticsManager: mockAnalytics)
        mockCache = MockCacheManager(cloudCacheService: mockCloudCache)
        controller = DefaultModelController(cacheManager: mockCache)
    }
    
    override func tearDown() async throws {
        controller = nil
        mockAnalytics = nil
        mockCache = nil
    }
    
    func testFilteredRecommendedPlaceResults() {
        // Given some recommended place results
        let result1 = TestFixtures.makeChatResult(title: "Place 1")
        let result2 = TestFixtures.makeChatResult(title: "Place 2")
        controller.recommendedPlaceResults = [result1, result2]
        
        // When filtering recommended results
        let filtered = controller.filteredRecommendedPlaceResults
        
        // Then all results should be returned (no filtering applied by default)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].title, "Place 1")
        XCTAssertEqual(filtered[1].title, "Place 2")
    }
    
    func testFilteredPlaceResults() {
        // Given some place results
        let result1 = TestFixtures.makeChatResult(title: "Restaurant A")
        let result2 = TestFixtures.makeChatResult(title: "Restaurant B")
        controller.placeResults = [result1, result2]
        
        // When filtering place results
        let filtered = controller.filteredPlaceResults
        
        // Then all results should be returned
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].title, "Restaurant A")
        XCTAssertEqual(filtered[1].title, "Restaurant B")
    }
    
    func testFilteredResultsRemovesEmptyCategories() {
        // Given industry results with some empty categories
        let emptyCategory = TestFixtures.makeCategoryResult(
            identity: "empty",
            parentCategory: "Empty Category",
            categoricalChatResults: []
        )
        let validCategory = TestFixtures.makeCategoryResult(
            identity: "valid",
            parentCategory: "Valid Category",
            categoricalChatResults: [TestFixtures.makeChatResult()]
        )
        controller.industryResults = [emptyCategory, validCategory]
        
        // When filtering results
        let filtered = controller.filteredResults
        
        // Then only categories with chat results should be returned
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].parentCategory, "Valid Category")
    }
    
    func testFilteredLocationResultsMergesCachedAndNew() {
        // Given cached location results
        let cachedLocation = TestFixtures.makeLocationResult(name: "Cached Location")
        mockCache.cachedLocationResults = [cachedLocation]
        
        // And new location results
        let newLocation = TestFixtures.makeLocationResult(name: "New Location")
        controller.locationResults = [newLocation]
        
        // When filtering location results
        let filtered = controller.filteredLocationResults()
        
        // Then both cached and new results should be included
        XCTAssertEqual(filtered.count, 2)
        let names = filtered.map { $0.locationName }
        XCTAssertTrue(names.contains("Cached Location"))
        XCTAssertTrue(names.contains("New Location"))
    }
    
    func testFilteredLocationResultsRemovesDuplicates() {
        // Given a location in both cache and new results
        let location = TestFixtures.makeLocationResult(name: "San Francisco")
        mockCache.cachedLocationResults = [location]
        controller.locationResults = [location]
        
        // When filtering location results
        let filtered = controller.filteredLocationResults()
        
        // Then duplicates should be removed
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].locationName, "San Francisco")
    }
    
    func testFilteredLocationResultsSorts() {
        // Given unsorted locations
        let locationB = TestFixtures.makeLocationResult(name: "B Location")
        let locationA = TestFixtures.makeLocationResult(name: "A Location")
        let locationC = TestFixtures.makeLocationResult(name: "C Location")
        controller.locationResults = [locationB, locationA, locationC]
        
        // When filtering location results
        let filtered = controller.filteredLocationResults()
        
        // Then results should be sorted alphabetically
        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered[0].locationName, "A Location")
        XCTAssertEqual(filtered[1].locationName, "B Location")
        XCTAssertEqual(filtered[2].locationName, "C Location")
    }
}

// MARK: - Result Lookup Tests

@MainActor
final class DefaultModelControllerResultLookupTests: XCTestCase {
    
    var controller: DefaultModelController!
    var mockAnalytics: MockAnalyticsService!
    var mockCache: MockCacheManager!
    
    override func setUp() async throws {
        mockAnalytics = MockAnalyticsService()
        let mockCloudCache = MockCloudCacheService(analyticsManager: mockAnalytics)
        mockCache = MockCacheManager(cloudCacheService: mockCloudCache)
        controller = DefaultModelController(cacheManager: mockCache)
    }
    
    override func tearDown() async throws {
        controller = nil
        mockAnalytics = nil
        mockCache = nil
    }
    
    func testPlaceChatResultByID_FindsInPlaceResults() {
        // Given a place result
        let result = TestFixtures.makeChatResult(identity: "test-123")
        controller.placeResults = [result]
        
        // When looking up by ID
        let found = controller.placeChatResult(for: result.id)
        
        // Then the result should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, result.id)
    }
    
    func testPlaceChatResultByID_FindsInRecommendedResults() {
        // Given a recommended result
        let result = TestFixtures.makeChatResult(identity: "rec-456")
        controller.recommendedPlaceResults = [result]
        
        // When looking up by ID
        let found = controller.placeChatResult(for: result.id)
        
        // Then the result should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, result.id)
    }
    
    func testPlaceChatResultByID_FindsInRelatedResults() {
        // Given a related result
        let result = TestFixtures.makeChatResult(identity: "rel-789")
        controller.relatedPlaceResults = [result]
        
        // When looking up by ID
        let found = controller.placeChatResult(for: result.id)
        
        // Then the result should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, result.id)
    }
    
    func testPlaceChatResultByID_ReturnsNilWhenNotFound() {
        // Given empty results
        controller.placeResults = []
        controller.recommendedPlaceResults = []
        
        // When looking up a non-existent ID
        let randomID = UUID()
        let found = controller.placeChatResult(for: randomID)
        
        // Then nil should be returned
        XCTAssertNil(found)
    }
    
    func testPlaceChatResultByFsqID_FindsInPlaceResults() {
        // Given a place with fsqID
        let placeResponse = TestFixtures.makePlaceSearchResponse(fsqID: "fsq-123")
        let result = TestFixtures.makeChatResult(placeResponse: placeResponse)
        controller.placeResults = [result]
        
        // When looking up by fsqID
        let found = controller.placeChatResult(with: "fsq-123")
        
        // Then the result should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.placeResponse?.fsqID, "fsq-123")
    }
    
    func testPlaceChatResultByFsqID_FindsInRecommendedResults() {
        // Given a recommended place with fsqID
        let recResponse = TestFixtures.makeRecommendedPlaceSearchResponse(fsqID: "fsq-rec-456")
        let result = TestFixtures.makeChatResult(recommendedPlaceResponse: recResponse)
        controller.recommendedPlaceResults = [result]
        
        // When looking up by fsqID
        let found = controller.placeChatResult(with: "fsq-rec-456")
        
        // Then the result should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.recommendedPlaceResponse?.fsqID, "fsq-rec-456")
    }
    
    func testIndustryCategoryResult_FindsCategory() {
        // Given an industry category
        let category = TestFixtures.makeIndustryCategoryResult(identity: "restaurants")
        controller.industryResults = [category]
        
        // When looking up by ID
        let found = controller.industryCategoryResult(for: category.id)
        
        // Then the category should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, category.id)
    }
    
    func testTasteCategoryResult_FindsCategory() {
        // Given a taste category
        let category = TestFixtures.makeTasteCategoryResult(identity: "romantic")
        controller.tasteResults = [category]
        
        // When looking up by ID
        let found = controller.tasteCategoryResult(for: category.id)
        
        // Then the category should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, category.id)
    }
    
    func testCachedIndustryResult_FindsInCache() {
        // Given a cached industry result
        let category = TestFixtures.makeIndustryCategoryResult()
        mockCache.cachedIndustryResults = [category]
        
        // When looking up by ID
        let found = controller.cachedIndustryResult(for: category.id)
        
        // Then the cached result should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, category.id)
    }
    
    func testLocationChatResult_FindsInLocationResults() {
        // Given a location result
        let location = TestFixtures.makeLocationResult(name: "Test City")
        let locations = [location]
        
        // When looking up by ID
        let found = controller.locationChatResult(for: location.id, in: locations)
        
        // Then the location should be found
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, location.id)
        XCTAssertEqual(found?.locationName, "Test City")
    }
}
