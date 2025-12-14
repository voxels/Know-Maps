//
//  AssistiveChatHostServiceTests.swift
//  Know MapsTests
//
//  Created for testing AssistiveChatHostService functionality
//

import XCTest
import CoreLocation
@testable import Know_Maps

// MARK: - Intent Determination Tests

@MainActor
final class AssistiveChatHostIntentDeterminationTests: XCTestCase {

    var service: AssistiveChatHostService!
    var mockMessagesDelegate: MockAssistiveChatHostMessagesDelegate!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockMessagesDelegate = MockAssistiveChatHostMessagesDelegate()
        service = AssistiveChatHostService(analyticsManager: mockAnalytics, messagesDelegate: mockMessagesDelegate)
    }

    override func tearDown() async throws {
        service = nil
        mockMessagesDelegate = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testDetermineIntentEnhanced_withOverride_returnsOverrideIntent() async throws {
        // Given
        let caption = "find pizza"
        let override: AssistiveChatHostService.Intent = .Place

        // When
        let intent = try await service.determineIntentEnhanced(for: caption, override: override)

        // Then
        XCTAssertEqual(intent, .Place, "Override intent should be returned when provided")
    }

    func testDetermineIntentEnhanced_withCategoryQuery_returnsSearchIntent() async throws {
        // Given
        let caption = "restaurants"

        // When
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        // Then
        // Most general queries should map to .Search or .AutocompleteTastes
        XCTAssertTrue(
            intent == .Search || intent == .AutocompleteTastes,
            "Category queries should map to Search or AutocompleteTastes intent"
        )
    }

    func testDetermineIntentEnhanced_withPlaceQuery_returnsPlaceIntent() async throws {
        // Given
        let caption = "Golden Gate Bridge"

        // When
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        // Then
        // Specific place names should map to .Place intent
        XCTAssertTrue(
            intent == .Place || intent == .Search,
            "Place-specific queries should map to Place or Search intent"
        )
    }

    func testDetermineIntentEnhanced_withEmptyQuery_doesNotCrash() async throws {
        // Given
        let caption = ""

        // When/Then - Should not throw
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        XCTAssertNotNil(intent, "Should return an intent even for empty queries")
    }

    func testDetermineIntentEnhanced_withLocationQuery_returnsLocationIntent() async throws {
        // Given
        let caption = "near Golden Gate Park"

        // When
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        // Then
        XCTAssertTrue(
            intent == .Location || intent == .Search,
            "Location queries should map to Location or Search intent"
        )
    }

    func testDetermineIntentEnhanced_withTasteQuery_returnsAutocompleteTastesIntent() async throws {
        // Given
        let caption = "romantic"

        // When
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        // Then
        XCTAssertTrue(
            intent == .AutocompleteTastes || intent == .Search,
            "Taste/vibe queries should map to AutocompleteTastes or Search intent"
        )
    }

    func testDetermineIntentEnhanced_withMultiEntityQuery_returnsSearchIntent() async throws {
        // Given
        let caption = "romantic italian restaurant with outdoor seating"

        // When
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        // Then
        // Complex multi-entity queries typically map to .Search
        XCTAssertTrue(
            intent == .Search || intent == .AutocompleteTastes,
            "Multi-entity queries should map to Search or AutocompleteTastes"
        )
    }

    func testDetermineIntentEnhanced_withSpecialCharacters_doesNotCrash() async throws {
        // Given
        let caption = "café @#$% & restaurant!!"

        // When/Then - Should not throw
        let intent = try await service.determineIntentEnhanced(for: caption, override: nil)

        XCTAssertNotNil(intent, "Should handle special characters gracefully")
    }
}

// MARK: - Query Parsing Tests

@MainActor
final class AssistiveChatHostQueryParsingTests: XCTestCase {

    var service: AssistiveChatHostService!
    var mockMessagesDelegate: MockAssistiveChatHostMessagesDelegate!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockMessagesDelegate = MockAssistiveChatHostMessagesDelegate()
        service = AssistiveChatHostService(analyticsManager: mockAnalytics, messagesDelegate: mockMessagesDelegate)
    }

    override func tearDown() async throws {
        service = nil
        mockMessagesDelegate = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testTags_withValidQuery_returnsTaggedWords() throws {
        // Given
        let query = "find italian restaurants"

        // When
        let tags = try service.tags(for: query)

        // Then
        XCTAssertNotNil(tags, "Should return tags for valid query")
        XCTAssertTrue(tags?.keys.count ?? 0 > 0, "Should have at least one tagged word")
    }

    func testTags_withEmptyQuery_returnsNil() throws {
        // Given
        let query = ""

        // When
        let tags = try service.tags(for: query)

        // Then
        XCTAssertNil(tags, "Should return nil for empty query")
    }

    func testParsedQuery_withTags_filtersCorrectly() throws {
        // Given
        let rawQuery = "find romantic italian restaurant near me"
        let tags = try service.tags(for: rawQuery)

        // When
        let parsedQuery = service.parsedQuery(for: rawQuery, tags: tags)

        // Then
        XCTAssertFalse(parsedQuery.isEmpty, "Parsed query should not be empty")
        XCTAssertFalse(parsedQuery.contains("near me"), "Should filter out location qualifiers")
    }

    func testParsedQuery_withoutTags_returnsOriginalQuery() throws {
        // Given
        let rawQuery = "test query"

        // When
        let parsedQuery = service.parsedQuery(for: rawQuery, tags: nil)

        // Then
        XCTAssertEqual(parsedQuery, rawQuery, "Should return original query when tags are nil")
    }

    func testParsedQuery_withNearKeyword_removesLocationInfo() throws {
        // Given
        let rawQuery = "pizza near Golden Gate Park"
        let tags = try service.tags(for: rawQuery)

        // When
        let parsedQuery = service.parsedQuery(for: rawQuery, tags: tags)

        // Then
        XCTAssertFalse(parsedQuery.contains("Golden Gate Park"), "Should remove location after 'near'")
    }

    func testMinPrice_withExpensiveQuery_returnsMinPrice() {
        // Given
        let query = "expensive restaurants"

        // When
        let minPrice = service.minPrice(for: query)

        // Then
        XCTAssertEqual(minPrice, 3, "Should return min price 3 for expensive queries")
    }

    func testMinPrice_withNotExpensiveQuery_returnsNil() {
        // Given
        let query = "not expensive restaurants"

        // When
        let minPrice = service.minPrice(for: query)

        // Then
        XCTAssertNil(minPrice, "Should return nil for 'not expensive' queries")
    }

    func testMaxPrice_withCheapQuery_returnsMaxPrice() {
        // Given
        let query = "cheap restaurants"

        // When
        let maxPrice = service.maxPrice(for: query)

        // Then
        XCTAssertEqual(maxPrice, 2, "Should return max price 2 for cheap queries")
    }

    func testMaxPrice_withNotExpensiveQuery_returnsMaxPrice() {
        // Given
        let query = "not that expensive restaurants"

        // When
        let maxPrice = service.maxPrice(for: query)

        // Then
        XCTAssertEqual(maxPrice, 3, "Should return max price 3 for 'not expensive' queries")
    }

    func testOpenNow_withOpenNowQuery_returnsTrue() {
        // Given
        let query = "restaurants open now"

        // When
        let openNow = service.openNow(for: query)

        // Then
        XCTAssertTrue(openNow ?? false, "Should return true for 'open now' queries")
    }

    func testDefaultParameters_withFilters_includesFilteredParameters() async throws {
        // Given
        let query = "pizza"
        let filters: [String: Any] = ["distance": 10.0, "open_now": true]

        // When
        let parameters = try await service.defaultParameters(for: query, filters: filters)

        // Then
        XCTAssertNotNil(parameters, "Should return parameters")
        if let params = parameters,
           let rawParameters = params["parameters"] as? [String: Any] {
            XCTAssertEqual(rawParameters["radius"] as? Double, 10000.0, "Should convert km to meters")
            XCTAssertEqual(rawParameters["open_now"] as? Bool, true, "Should include open_now filter")
        } else {
            XCTFail("Parameters structure is incorrect")
        }
    }
}

// MARK: - Category Mapping Tests

@MainActor
final class AssistiveChatHostCategoryMappingTests: XCTestCase {

    var service: AssistiveChatHostService!
    var mockMessagesDelegate: MockAssistiveChatHostMessagesDelegate!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockMessagesDelegate = MockAssistiveChatHostMessagesDelegate()
        service = AssistiveChatHostService(analyticsManager: mockAnalytics, messagesDelegate: mockMessagesDelegate)
    }

    override func tearDown() async throws {
        service = nil
        mockMessagesDelegate = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testCategoryCodes_isNotEmpty() {
        // Given/When
        let categoryCodes = service.categoryCodes

        // Then
        XCTAssertFalse(categoryCodes.isEmpty, "Category codes should be loaded from taxonomy file")
    }

    func testCategoryCodes_withValidQuery_returnsMatchingCodes() async {
        // Given
        let query = "restaurant"
        let tags = try? service.tags(for: query)

        // When
        let codes = await service.categoryCodes(for: query, tags: tags)

        // Then - restaurants is a common category, should return codes
        // Note: actual codes depend on taxonomy file, so we just verify structure
        XCTAssertNotNil(codes, "Should return category codes for restaurant query")
    }

    func testCategoryCodes_withEmptyQuery_returnsNil() async {
        // Given
        let query = ""

        // When
        let codes = await service.categoryCodes(for: query, tags: nil)

        // Then
        XCTAssertNil(codes, "Should return nil for empty query")
    }

    func testSection_withValidTitle_returnsSection() {
        // Given
        let title = "food"

        // When
        let section = service.section(for: title)

        // Then
        XCTAssertEqual(section, .food, "Should return correct section for 'food'")
    }

    func testSection_withEmptyTitle_returnsTopPicks() {
        // Given
        let title = ""

        // When
        let section = service.section(for: title)

        // Then
        XCTAssertEqual(section, .topPicks, "Should return topPicks as default for empty title")
    }

    func testSection_withUnknownTitle_usesMLClassifier() {
        // Given
        let title = "romantic dinner spots"

        // When
        let section = service.section(for: title)

        // Then
        // Should use ML classifier and return a valid section
        XCTAssertNotNil(section, "Should return a section even for unknown titles")
    }

    func testOrganizeCategoryCodeList_returnsValidStructure() throws {
        // Given/When
        let categoryCodes = try AssistiveChatHostService.organizeCategoryCodeList()

        // Then
        XCTAssertFalse(categoryCodes.isEmpty, "Should organize category codes from taxonomy")
        for categoryDict in categoryCodes {
            XCTAssertFalse(categoryDict.keys.isEmpty, "Each category should have keys")
        }
    }
}

// MARK: - Intent Management Tests

@MainActor
final class AssistiveChatHostIntentManagementTests: XCTestCase {

    var service: AssistiveChatHostService!
    var mockMessagesDelegate: MockAssistiveChatHostMessagesDelegate!
    var mockAnalytics: MockAnalyticsService!
    var modelController: DefaultModelController!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockMessagesDelegate = MockAssistiveChatHostMessagesDelegate()
        service = AssistiveChatHostService(analyticsManager: mockAnalytics, messagesDelegate: mockMessagesDelegate)
        modelController = TestFixtures.makeModelController()
    }

    override func tearDown() async throws {
        service = nil
        mockMessagesDelegate = nil
        mockAnalytics = nil
        modelController = nil
        try await super.tearDown()
    }

    func testAppendIntentParameters_addsIntentToHistory() async {
        // Given
        let intent = TestFixtures.makeAssistiveChatHostIntent(caption: "test query")
        let initialCount = service.queryIntentParameters.queryIntents.count

        // When
        await service.appendIntentParameters(intent: intent, modelController: modelController)

        // Then
        XCTAssertEqual(
            service.queryIntentParameters.queryIntents.count,
            initialCount + 1,
            "Should add one intent to history"
        )
        XCTAssertTrue(mockMessagesDelegate.updateQueryParametersHistoryCalled, "Should notify delegate")
    }

    func testResetIntentParameters_clearsHistory() async {
        // Given
        let intent = TestFixtures.makeAssistiveChatHostIntent(caption: "test query")
        await service.appendIntentParameters(intent: intent, modelController: modelController)

        // When
        service.resetIntentParameters()

        // Then
        XCTAssertEqual(
            service.queryIntentParameters.queryIntents.count,
            0,
            "Should clear all intents from history"
        )
    }

    func testCreateIntent_withPlaceResult_createsPlaceIntent() async throws {
        // Given
        let placeResponse = TestFixtures.makePlaceSearchResponse(fsqID: "test-id", name: "Test Place")
        let chatResult = TestFixtures.makeChatResult(
            title: "Test Place",
            placeResponse: placeResponse
        )
        let filters: [String: Any] = [:]
        let destination = TestFixtures.makeLocationResult()

        // When
        let intent = try await service.createIntent(
            for: chatResult,
            filters: filters,
            selectedDestination: destination
        )

        // Then
        XCTAssertEqual(intent.intent, .Place, "Should create Place intent for place results")
        XCTAssertEqual(intent.selectedPlaceSearchResponse?.fsqID, "test-id", "Should include place response")
    }

    func testCreateIntent_withCategoryResult_createsSearchIntent() async throws {
        // Given
        let chatResult = TestFixtures.makeChatResult(title: "Restaurants")
        let filters: [String: Any] = [:]
        let destination = TestFixtures.makeLocationResult()

        // When
        let intent = try await service.createIntent(
            for: chatResult,
            filters: filters,
            selectedDestination: destination
        )

        // Then
        XCTAssertEqual(intent.intent, .Search, "Should create Search intent for category results")
        XCTAssertNil(intent.selectedPlaceSearchResponse, "Should not include place response")
    }
}

// MARK: - Mock Messages Delegate

@MainActor
final class MockAssistiveChatHostMessagesDelegate: AssistiveChatHostMessagesDelegate, @unchecked Sendable {

    var updateQueryParametersHistoryCalled = false
    var addReceivedMessageCalled = false

    func updateQueryParametersHistory(with queryParameters: AssistiveChatHostQueryParameters, modelController: ModelController) async {
        updateQueryParametersHistoryCalled = true
    }

    func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, filters: [String : Any], modelController: ModelController, overrideIntent: AssistiveChatHostService.Intent?, selectedDestinationLocation: LocationResult?) async throws {
        addReceivedMessageCalled = true
    }
}
