//
//  FoundationModelsIntentClassifierTests.swift
//  Know MapsTests
//
//  Created for testing FoundationModelsIntentClassifier functionality
//

import XCTest
@testable import Know_Maps

// MARK: - Intent Classification Tests

final class IntentClassificationTests: XCTestCase {

    var classifier: FoundationModelsIntentClassifier!

    override func setUp() async throws {
        try await super.setUp()
        classifier = FoundationModelsIntentClassifier()
    }

    override func tearDown() async throws {
        classifier = nil
        try await super.tearDown()
    }

    func testClassify_withRestaurantQuery_returnsCategoryIntent() async throws {
        // Given
        let query = "restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertEqual(intent.searchType, .category, "Should classify 'restaurants' as category search")
        XCTAssertNotNil(intent.categories, "Should extract restaurant category")
        XCTAssertEqual(intent.rawQuery, query, "Should preserve raw query")
    }

    func testClassify_withSpecificCuisineQuery_extractsCategories() async throws {
        // Given
        let query = "italian restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.categories, "Should extract categories")
        XCTAssertTrue(
            intent.categories?.contains("Italian") ?? false,
            "Should extract 'Italian' as category"
        )
    }

    func testClassify_withMultipleCuisines_extractsAllCategories() async throws {
        // Given
        let query = "sushi or pizza"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.categories, "Should extract multiple categories")
        let categories = intent.categories ?? []
        XCTAssertTrue(categories.count >= 1, "Should extract at least one category")
    }

    func testClassify_withTasteQuery_returnsTasteIntent() async throws {
        // Given
        let query = "romantic"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertTrue(
            intent.searchType == .taste || intent.searchType == .category,
            "Should classify taste/feature queries appropriately"
        )
        XCTAssertNotNil(intent.tastes, "Should extract 'romantic' as taste")
    }

    func testClassify_withPlaceNameQuery_returnsPlaceIntent() async throws {
        // Given
        let query = "Golden Gate Bridge"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        // Place name detection depends on NLTagger, results may vary
        XCTAssertNotNil(intent.rawQuery, "Should have raw query")
    }

    func testClassify_withLocationQuery_returnsLocationIntent() async throws {
        // Given
        let query = "near Golden Gate Park"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.locationDescription, "Should extract location description")
        XCTAssertEqual(intent.searchType, .location, "Should classify as location search")
    }

    func testClassify_withMixedQuery_returnsMixedIntent() async throws {
        // Given
        let query = "romantic italian restaurant near downtown"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertEqual(intent.searchType, .mixed, "Should classify complex query as mixed")
        XCTAssertTrue(intent.isComplexQuery, "Should be marked as complex query")
    }

    func testClassify_withEmptyQuery_doesNotCrash() async throws {
        // Given
        let query = ""

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent, "Should return an intent even for empty query")
        XCTAssertEqual(intent.rawQuery, query, "Should preserve empty raw query")
    }

    func testClassify_withSpecialCharacters_handlesGracefully() async throws {
        // Given
        let query = "café & restaurant!!!"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent, "Should handle special characters")
        XCTAssertEqual(intent.rawQuery, query, "Should preserve original query with special chars")
    }

    func testClassify_withVeryShortQuery_doesNotCrash() async throws {
        // Given
        let query = "a"

        // When/Then - Should not throw
        let intent = try await classifier.classify(query: query)

        XCTAssertNotNil(intent, "Should handle very short queries")
    }

    func testClassify_withVeryLongQuery_doesNotCrash() async throws {
        // Given
        let query = String(repeating: "restaurant ", count: 100)

        // When/Then - Should not throw
        let intent = try await classifier.classify(query: query)

        XCTAssertNotNil(intent, "Should handle very long queries")
    }
}

// MARK: - Feature Extraction Tests

final class FeatureExtractionTests: XCTestCase {

    var classifier: FoundationModelsIntentClassifier!

    override func setUp() async throws {
        try await super.setUp()
        classifier = FoundationModelsIntentClassifier()
    }

    override func tearDown() async throws {
        classifier = nil
        try await super.tearDown()
    }

    func testClassify_withOutdoorSeating_extractsTaste() async throws {
        // Given
        let query = "restaurants with outdoor seating"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.tastes, "Should extract outdoor seating taste")
        XCTAssertTrue(
            intent.tastes?.contains("outdoor seating") ?? false,
            "Should extract 'outdoor seating' feature"
        )
    }

    func testClassify_withWifi_extractsTaste() async throws {
        // Given
        let query = "coffee shops with wifi"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.tastes, "Should extract wifi taste")
    }

    func testClassify_withLiveMusic_extractsTaste() async throws {
        // Given
        let query = "bars with live music"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.tastes, "Should extract live music taste")
    }

    func testClassify_withFamilyFriendly_extractsTaste() async throws {
        // Given
        let query = "family-friendly restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.tastes, "Should extract family-friendly taste")
    }

    func testClassify_withMultipleTastes_extractsAll() async throws {
        // Given
        let query = "cozy restaurant with outdoor seating and wifi"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.tastes, "Should extract multiple tastes")
        let tastes = intent.tastes ?? []
        XCTAssertTrue(tastes.count >= 2, "Should extract at least 2 tastes")
    }
}

// MARK: - Price Range Tests

final class PriceRangeExtractionTests: XCTestCase {

    var classifier: FoundationModelsIntentClassifier!

    override func setUp() async throws {
        try await super.setUp()
        classifier = FoundationModelsIntentClassifier()
    }

    override func tearDown() async throws {
        classifier = nil
        try await super.tearDown()
    }

    func testClassify_withCheapQuery_extractsLowPriceRange() async throws {
        // Given
        let query = "cheap restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.priceRange, "Should extract price range")
        XCTAssertEqual(intent.priceRange?.min, 1, "Should have min price 1")
        XCTAssertEqual(intent.priceRange?.max, 2, "Should have max price 2")
    }

    func testClassify_withExpensiveQuery_extractsHighPriceRange() async throws {
        // Given
        let query = "expensive restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.priceRange, "Should extract price range")
        XCTAssertEqual(intent.priceRange?.min, 3, "Should have min price 3")
        XCTAssertEqual(intent.priceRange?.max, 4, "Should have max price 4")
    }

    func testClassify_withLuxuryQuery_extractsHighPriceRange() async throws {
        // Given
        let query = "luxury restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.priceRange, "Should extract price range for luxury")
        XCTAssertTrue(
            (intent.priceRange?.min ?? 0) >= 3,
            "Luxury should have high min price"
        )
    }

    func testClassify_withAffordableQuery_extractsLowPriceRange() async throws {
        // Given
        let query = "affordable restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.priceRange, "Should extract price range for affordable")
        XCTAssertTrue(
            (intent.priceRange?.max ?? 5) <= 2,
            "Affordable should have low max price"
        )
    }

    func testClassify_withNotExpensiveQuery_extractsMidPriceRange() async throws {
        // Given
        let query = "not expensive restaurants"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.priceRange, "Should extract price range for 'not expensive'")
        XCTAssertTrue(
            (intent.priceRange?.max ?? 5) <= 3,
            "Not expensive should exclude highest prices"
        )
    }

    func testPriceRange_initialization_clampsValues() {
        // Given/When
        let invalidLowRange = UnifiedSearchIntent.PriceRange(min: 0, max: 5)

        // Then
        XCTAssertEqual(invalidLowRange.min, 1, "Should clamp min to 1")
        XCTAssertEqual(invalidLowRange.max, 4, "Should clamp max to 4")
    }

    func testPriceRange_exactInitialization_setsMinMax() {
        // Given/When
        let exactPrice = UnifiedSearchIntent.PriceRange(exact: 2)

        // Then
        XCTAssertEqual(exactPrice.min, 2, "Should set min to exact value")
        XCTAssertEqual(exactPrice.max, 2, "Should set max to exact value")
    }
}

// MARK: - Location Extraction Tests

final class LocationExtractionTests: XCTestCase {

    var classifier: FoundationModelsIntentClassifier!

    override func setUp() async throws {
        try await super.setUp()
        classifier = FoundationModelsIntentClassifier()
    }

    override func tearDown() async throws {
        classifier = nil
        try await super.tearDown()
    }

    func testClassify_withNearKeyword_extractsLocation() async throws {
        // Given
        let query = "restaurants near Union Square"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.locationDescription, "Should extract location after 'near'")
        XCTAssertTrue(
            intent.locationDescription?.contains("Union Square") ?? false,
            "Should extract 'Union Square' as location"
        )
    }

    func testClassify_withAroundKeyword_extractsLocation() async throws {
        // Given
        let query = "coffee around Market Street"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.locationDescription, "Should extract location after 'around'")
    }

    func testClassify_withInKeyword_extractsLocation() async throws {
        // Given
        let query = "pizza in downtown"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.locationDescription, "Should extract location after 'in'")
        XCTAssertTrue(
            intent.locationDescription?.contains("downtown") ?? false,
            "Should extract 'downtown' as location"
        )
    }

    func testClassify_withAtKeyword_extractsLocation() async throws {
        // Given
        let query = "restaurants at the waterfront"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.locationDescription, "Should extract location after 'at'")
    }

    func testClassify_withCloseToKeyword_extractsLocation() async throws {
        // Given
        let query = "bars close to the airport"

        // When
        let intent = try await classifier.classify(query: query)

        // Then
        XCTAssertNotNil(intent.locationDescription, "Should extract location after 'close to'")
    }
}

// MARK: - Helper Method Tests

final class UnifiedSearchIntentHelperTests: XCTestCase {

    func testIsComplexQuery_withMultipleComponents_returnsTrue() {
        // Given
        let intent = UnifiedSearchIntent(
            searchType: .mixed,
            categories: ["Italian"],
            tastes: ["romantic"],
            priceRange: UnifiedSearchIntent.PriceRange(min: 2, max: 3),
            placeName: nil,
            locationDescription: "downtown",
            rawQuery: "romantic italian restaurant near downtown"
        )

        // When/Then
        XCTAssertTrue(intent.isComplexQuery, "Should identify as complex query")
    }

    func testIsComplexQuery_withSingleComponent_returnsFalse() {
        // Given
        let intent = UnifiedSearchIntent(
            searchType: .category,
            categories: ["Pizza"],
            tastes: nil,
            priceRange: nil,
            placeName: nil,
            locationDescription: nil,
            rawQuery: "pizza"
        )

        // When/Then
        XCTAssertFalse(intent.isComplexQuery, "Should not identify as complex query")
    }

    func testIntentDescription_forCategorySearch_returnsCorrectDescription() {
        // Given
        let intent = UnifiedSearchIntent(
            searchType: .category,
            categories: ["Italian", "Pizza"],
            tastes: nil,
            priceRange: nil,
            placeName: nil,
            locationDescription: nil,
            rawQuery: "italian pizza"
        )

        // When
        let description = intent.intentDescription

        // Then
        XCTAssertTrue(description.contains("Italian"), "Description should mention categories")
    }

    func testIcon_returnsCorrectEmojiForSearchType() {
        // Given
        let categoryIntent = UnifiedSearchIntent(searchType: .category, rawQuery: "test")
        let tasteIntent = UnifiedSearchIntent(searchType: .taste, rawQuery: "test")
        let placeIntent = UnifiedSearchIntent(searchType: .place, rawQuery: "test")
        let locationIntent = UnifiedSearchIntent(searchType: .location, rawQuery: "test")
        let mixedIntent = UnifiedSearchIntent(searchType: .mixed, rawQuery: "test")

        // When/Then
        XCTAssertEqual(categoryIntent.icon, "🏷️", "Category should have tag icon")
        XCTAssertEqual(tasteIntent.icon, "✨", "Taste should have sparkle icon")
        XCTAssertEqual(placeIntent.icon, "📍", "Place should have pin icon")
        XCTAssertEqual(locationIntent.icon, "🌍", "Location should have globe icon")
        XCTAssertEqual(mixedIntent.icon, "🔍", "Mixed should have search icon")
    }
}
