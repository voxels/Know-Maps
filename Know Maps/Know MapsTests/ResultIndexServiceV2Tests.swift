//
//  ResultIndexServiceV2Tests.swift
//  Know MapsTests
//
//  Comprehensive tests for ResultIndexServiceV2
//

import XCTest
@testable import Know_Maps

@MainActor
final class ResultIndexServiceV2Tests: XCTestCase {

    var service: DefaultResultIndexServiceV2!

    override func setUp() async throws {
        service = TestFixtures.makeResultIndexService()
    }

    override func tearDown() async throws {
        service = nil
    }

    // MARK: - Place Result Lookup Tests (5 tests)

    func testFilteredPlaceResults_withMultipleResults_returnsAll() {
        // Given
        let placeResults = [
            TestFixtures.makeChatResult(index: 0, identity: "place-1", title: "Coffee Shop"),
            TestFixtures.makeChatResult(index: 1, identity: "place-2", title: "Restaurant")
        ]
        service.updateIndex(
            placeResults: placeResults,
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let results = service.filteredPlaceResults()

        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].identity, "place-1")
        XCTAssertEqual(results[1].identity, "place-2")
    }

    func testPlaceChatResultForID_inRecommended_returnsResult() {
        // Given
        let recommendedResult = TestFixtures.makeChatResult(identity: "rec-1", title: "Top Pick")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [recommendedResult],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.placeChatResult(for: "rec-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "rec-1")
        XCTAssertEqual(result?.title, "Top Pick")
    }

    func testPlaceChatResultForID_inPlaceResults_returnsResult() {
        // Given
        let placeResult = TestFixtures.makeChatResult(identity: "place-1", title: "Regular Place")
        service.updateIndex(
            placeResults: [placeResult],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.placeChatResult(for: "place-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "place-1")
    }

    func testPlaceChatResultForID_inRelated_returnsResult() {
        // Given
        let relatedResult = TestFixtures.makeChatResult(identity: "related-1", title: "Related Place")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [relatedResult],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.placeChatResult(for: "related-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "related-1")
    }

    func testPlaceChatResultWithFsqID_findsResult() {
        // Given
        let placeResponse = TestFixtures.makePlaceSearchResponse(fsqID: "fsq-123", name: "Test Place")
        let chatResult = TestFixtures.makeChatResult(identity: "place-1", title: "Test Place", placeResponse: placeResponse)
        service.updateIndex(
            placeResults: [chatResult],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.placeChatResult(with: "fsq-123")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "place-1")
        XCTAssertEqual(result?.placeResponse?.fsqID, "fsq-123")
    }

    // MARK: - Chat Result Lookup Tests (3 tests)

    func testChatResultTitle_findsInIndustryResults() {
        // Given
        let chatResult = TestFixtures.makeChatResult(identity: "chat-1", title: "Pizza Restaurant")
        let categoryResult = TestFixtures.makeCategoryResult(
            identity: "category-1",
            parentCategory: "Restaurants",
            categoricalChatResults: [chatResult]
        )
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [categoryResult],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.chatResult(title: "Pizza Restaurant")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Pizza Restaurant")
    }

    func testIndustryChatResult_findsById() {
        // Given
        let chatResult = TestFixtures.makeChatResult(identity: "industry-1", title: "Coffee Shop")
        let categoryResult = TestFixtures.makeCategoryResult(
            identity: "category-1",
            parentCategory: "Food",
            categoricalChatResults: [chatResult]
        )
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [categoryResult],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.industryChatResult(for: "industry-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "industry-1")
    }

    func testTasteChatResult_findsByCategoryId() {
        // Given
        let chatResult = TestFixtures.makeChatResult(identity: "taste-chat-1", title: "Romantic", section: .tastes)
        let categoryResult = TestFixtures.makeTasteCategoryResult(identity: "taste-1", title: "Romantic")
        categoryResult.replaceChatResults(with: [chatResult])
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [categoryResult],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.tasteChatResult(for: "taste-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.section, .tastes)
    }

    // MARK: - Category Result Lookup Tests (2 tests)

    func testIndustryCategoryResult_findsById() {
        // Given
        let categoryResult = TestFixtures.makeIndustryCategoryResult(identity: "restaurants", title: "Restaurants")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [categoryResult],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.industryCategoryResult(for: "restaurants")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "restaurants")
        XCTAssertEqual(result?.parentCategory, "Restaurants")
    }

    func testTasteCategoryResult_findsById() {
        // Given
        let tasteResult = TestFixtures.makeTasteCategoryResult(identity: "cozy", title: "Cozy")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [tasteResult],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.tasteCategoryResult(for: "cozy")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "cozy")
    }

    // MARK: - Cached Result Lookup Tests (6 tests)

    func testCachedIndustryResult_findsById() {
        // Given
        let cachedResult = TestFixtures.makeIndustryCategoryResult(identity: "cached-industry-1", title: "Cached Restaurant")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [cachedResult],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.cachedIndustryResult(for: "cached-industry-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "cached-industry-1")
    }

    func testCachedPlaceResult_findsById() {
        // Given
        let cachedPlace = TestFixtures.makeCategoryResult(identity: "cached-place-1", parentCategory: "Places")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [cachedPlace],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.cachedPlaceResult(for: "cached-place-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "cached-place-1")
    }

    func testCachedChatResult_findsById() {
        // Given
        let chatResult = TestFixtures.makeChatResult(identity: "chat-1", title: "Test Place")
        let cachedCategory = TestFixtures.makeCategoryResult(
            identity: "cached-category-1",
            parentCategory: "Test",
            categoricalChatResults: [chatResult]
        )
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [cachedCategory],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When
        let result = service.cachedChatResult(for: "cached-category-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "chat-1")
    }

    func testCachedTasteResult_findsById() {
        // Given
        let cachedTaste = TestFixtures.makeTasteCategoryResult(identity: "romantic", title: "Romantic")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [cachedTaste],
            cachedRecommendationData: []
        )

        // When
        let result = service.cachedTasteResult(for: "romantic")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "romantic")
    }

    func testCachedTasteResultTitle_findsByTitle() {
        // Given
        let cachedTaste = TestFixtures.makeTasteCategoryResult(identity: "cozy-1", title: "Cozy Atmosphere")
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [cachedTaste],
            cachedRecommendationData: []
        )

        // When
        let result = service.cachedTasteResultTitle("Cozy Atmosphere")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.parentCategory, "Cozy Atmosphere")
    }

    func testCachedRecommendationData_findsByIdentity() {
        // Given
        let recommendationData = TestFixtures.makeRecommendationData(identity: "rec-data-1", rating: 5)
        service.updateIndex(
            placeResults: [],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: [recommendationData]
        )

        // When
        let result = service.cachedRecommendationData(for: "rec-data-1")

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.identity, "rec-data-1")
        XCTAssertEqual(result?.rating, 5)
    }

    // MARK: - Location Result Lookup Tests (2 tests)

    func testLocationChatResult_findsById() {
        // Given
        let location1 = TestFixtures.makeLocationResult(name: "San Francisco")
        let location2 = TestFixtures.makeLocationResult(name: "New York")
        let locationResults = [location1, location2]

        // When
        let result = service.locationChatResult(for: location1.id, in: locationResults)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.locationName, "San Francisco")
    }

    func testLocationChatResult_withTitle_findsExisting() {
        // Given
        let location = TestFixtures.makeLocationResult(name: "Tokyo")
        let locationResults = [location]

        // When
        let result = await service.locationChatResult(
            with: "Tokyo",
            in: locationResults,
            locationService: MockLocationService(),
            analyticsManager: MockAnalyticsService()
        )

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.locationName, "Tokyo")
    }

    // MARK: - Index Update Tests (2 tests)

    func testUpdateIndex_rebuildsAllIndices() {
        // Given
        let placeResult = TestFixtures.makeChatResult(identity: "place-1", title: "Place")
        let industryResult = TestFixtures.makeIndustryCategoryResult(identity: "industry-1", title: "Industry")

        // When
        service.updateIndex(
            placeResults: [placeResult],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [industryResult],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // Then - verify lookups work after index update
        let foundPlace = service.placeChatResult(for: "place-1")
        let foundIndustry = service.industryCategoryResult(for: "industry-1")

        XCTAssertNotNil(foundPlace)
        XCTAssertNotNil(foundIndustry)
        XCTAssertEqual(foundPlace?.identity, "place-1")
        XCTAssertEqual(foundIndustry?.identity, "industry-1")
    }

    func testUpdateIndex_replacesOldData() {
        // Given - initial data
        let oldPlace = TestFixtures.makeChatResult(identity: "old-1", title: "Old Place")
        service.updateIndex(
            placeResults: [oldPlace],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // When - update with new data
        let newPlace = TestFixtures.makeChatResult(identity: "new-1", title: "New Place")
        service.updateIndex(
            placeResults: [newPlace],
            recommendedPlaceResults: [],
            relatedPlaceResults: [],
            industryResults: [],
            tasteResults: [],
            cachedIndustryResults: [],
            cachedPlaceResults: [],
            cachedTasteResults: [],
            cachedRecommendationData: []
        )

        // Then - old data should be gone, new data should be present
        let oldResult = service.placeChatResult(for: "old-1")
        let newResult = service.placeChatResult(for: "new-1")

        XCTAssertNil(oldResult)
        XCTAssertNotNil(newResult)
        XCTAssertEqual(newResult?.identity, "new-1")
    }
}
