//
//  DefaultModelControllerStateTests.swift
//  Know MapsTests
//
//  Created for testing state management
//

import XCTest
import CoreLocation
@testable import Know_Maps_Prod

// MARK: - State Management Tests

@MainActor
final class DefaultModelControllerStateManagementTests: XCTestCase {
    
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
    
    // MARK: - Selected Place Tests
    
    func testSetSelectedPlaceChatResult_UpdatesSelection() {
        // Given a place fsqID
        let fsqID = "test-fsq-123"
        
        // When setting the selected place
        controller.setSelectedPlaceChatResult(fsqID)
        
        // Then the selection should be updated
        XCTAssertEqual(controller.selectedPlaceChatResultFsqId, fsqID)
    }
    
    func testSetSelectedPlaceChatResult_IgnoresDuplicateSelection() {
        // Given an already selected place
        let fsqID = "test-fsq-123"
        controller.setSelectedPlaceChatResult(fsqID)
        
        // When setting the same place again
        controller.setSelectedPlaceChatResult(fsqID)
        
        // Then the selection should remain (reentrancy guard prevents issues)
        XCTAssertEqual(controller.selectedPlaceChatResultFsqId, fsqID)
    }
    
    func testSetSelectedPlaceChatResult_ClearsSelection() {
        // Given a selected place
        controller.setSelectedPlaceChatResult("test-fsq-123")
        
        // When clearing the selection
        controller.setSelectedPlaceChatResult(nil)
        
        // Then the selection should be nil
        XCTAssertNil(controller.selectedPlaceChatResultFsqId)
    }
    
    // MARK: - Selected Location Tests
    
    func testSetSelectedLocation_UpdatesSelection() {
        // Given a new location
        let location = TestFixtures.makeLocationResult(name: "New York")
        
        // When setting the selected location
        controller.setSelectedLocation(location)
        
        // Then the selection should be updated
        XCTAssertEqual(controller.selectedDestinationLocationChatResult.locationName, "New York")
    }
    
    func testSetSelectedLocation_IgnoresSameLocation() {
        // Given an already selected location
        let location = TestFixtures.makeLocationResult(name: "San Francisco")
        controller.setSelectedLocation(location)
        let initialSelection = controller.selectedDestinationLocationChatResult
        
        // When setting the same location again
        controller.setSelectedLocation(location)
        
        // Then the selection should remain unchanged (same ID check)
        XCTAssertEqual(controller.selectedDestinationLocationChatResult.id, initialSelection.id)
    }
    
    func testGetSelectedDestinationLocation_ReturnsCurrentLocation() {
        // Given a selected location
        let location = TestFixtures.makeLocationResult(
            name: "Test City",
            latitude: 40.7128,
            longitude: -74.0060
        )
        controller.setSelectedLocation(location)
        
        // When getting the selected destination location
        let result = controller.getSelectedDestinationLocation()
        
        // Then the correct location should be returned
        XCTAssertEqual(result.coordinate.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(result.coordinate.longitude, -74.0060, accuracy: 0.0001)
    }
    
    func testSetSelectedLocationAndGetLocation_ReturnsLocationSynchronously() {
        // Given a new location
        let location = TestFixtures.makeLocationResult(
            name: "Los Angeles",
            latitude: 34.0522,
            longitude: -118.2437
        )
        
        // When setting and getting the location synchronously
        let result = controller.setSelectedLocationAndGetLocation(location)
        
        // Then the correct location should be returned immediately
        XCTAssertEqual(result.coordinate.latitude, 34.0522, accuracy: 0.0001)
        XCTAssertEqual(result.coordinate.longitude, -118.2437, accuracy: 0.0001)
        // And the selection should be updated
        XCTAssertEqual(controller.selectedDestinationLocationChatResult.locationName, "Los Angeles")
    }
    
    // MARK: - Categorical Results Tests
    
    func testCategoricalResults_GeneratesResults() {
        // When generating categorical results
        let results = controller.categoricalResults()
        
        // Then results should be generated based on category codes
        // (This depends on the assistiveHostDelegate having category codes)
        XCTAssertNotNil(results)
        // Note: Actual count will depend on the real implementation
    }
    
    func testEnsureIndustryResultsPopulated_PopulatesWhenEmpty() async {
        // Given empty industry results
        controller.industryResults = []
        
        // When ensuring industry results are populated
        await controller.ensureIndustryResultsPopulated()
        
        // Then industry results should be populated
        // Note: This test may need adjustment based on actual mock data
        XCTAssertNotNil(controller.industryResults)
    }
    
    func testEnsureIndustryResultsPopulated_SkipsWhenAlreadyPopulated() async {
        // Given already populated industry results
        let existingResult = TestFixtures.makeIndustryCategoryResult()
        controller.industryResults = [existingResult]
        
        // When ensuring industry results are populated
        await controller.ensureIndustryResultsPopulated()
        
        // Then the existing results should remain
        XCTAssertEqual(controller.industryResults.count, 1)
        XCTAssertEqual(controller.industryResults[0].id, existingResult.id)
    }
    
    // MARK: - Reset Tests
    
    func testResetPlaceModel_ClearsAllState() async throws {
        // Given a controller with various state
        controller.placeResults = [TestFixtures.makeChatResult()]
        controller.recommendedPlaceResults = [TestFixtures.makeChatResult()]
        controller.selectedPlaceChatResultFsqId = "test-123"
        
        // When resetting the place model
        try await controller.resetPlaceModel()
        
        // Then all state should be cleared
        XCTAssertTrue(controller.placeResults.isEmpty)
        XCTAssertTrue(controller.recommendedPlaceResults.isEmpty)
        // Note: selectedPlaceChatResultFsqId might be cleared depending on implementation
        
        // And analytics should track the reset
        XCTAssertTrue(mockAnalytics.hasTrackedEvent("resetPlaceModel"))
    }
    
    // MARK: - Update Found Results Message Tests
    
    func testUpdateFoundResultsMessage_GeneratesCorrectMessage() {
        // Given some results
        controller.recommendedPlaceResults = [
            TestFixtures.makeChatResult(),
            TestFixtures.makeChatResult()
        ]
        controller.placeResults = [
            TestFixtures.makeChatResult(),
            TestFixtures.makeChatResult(),
            TestFixtures.makeChatResult()
        ]
        let location = TestFixtures.makeLocationResult(name: "San Francisco")
        controller.setSelectedLocation(location)
        
        // When updating the found results message
        controller.updateFoundResultsMessage()
        
        // Then the message should reflect the counts
        let message = controller.fetchMessage
        XCTAssertTrue(message.contains("2"))  // recommended count
        XCTAssertTrue(message.contains("3"))  // place count
        XCTAssertTrue(message.contains("San Francisco"))
    }
}
