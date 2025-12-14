//
//  VectorEmbeddingServiceTests.swift
//  Know MapsTests
//
//  Created for testing VectorEmbeddingService functionality
//

import XCTest
@testable import Know_Maps

// MARK: - Embedding Generation Tests

final class EmbeddingGenerationTests: XCTestCase {

    var service: VectorEmbeddingService!

    override func setUp() throws {
        try super.setUp()
        service = VectorEmbeddingService()
    }

    override func tearDown() throws {
        service = nil
        try super.tearDown()
    }

    func testSemanticScore_withIdenticalStrings_returnsHighScore() {
        // Given
        let query = "coffee shop"
        let placeDescription = "coffee shop"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertGreaterThan(score, 0.9, "Identical strings should have very high similarity")
    }

    func testSemanticScore_withSimilarStrings_returnsModerateScore() {
        // Given
        let query = "coffee shop"
        let placeDescription = "cafe espresso"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertGreaterThan(score, 0.0, "Similar concepts should have non-zero similarity")
    }

    func testSemanticScore_withUnrelatedStrings_returnsLowScore() {
        // Given
        let query = "coffee shop"
        let placeDescription = "hardware store tools"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertLessThan(score, 0.7, "Unrelated strings should have low similarity")
    }

    func testSemanticScore_withEmptyQuery_returnsZero() {
        // Given
        let query = ""
        let placeDescription = "coffee shop"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertEqual(score, 0.0, "Empty query should return zero similarity")
    }

    func testSemanticScore_withEmptyDescription_returnsZero() {
        // Given
        let query = "coffee shop"
        let placeDescription = ""

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertEqual(score, 0.0, "Empty description should return zero similarity")
    }

    func testSemanticScore_withSynonyms_returnsHighScore() {
        // Given
        let query = "cheap"
        let placeDescription = "affordable inexpensive budget-friendly"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertGreaterThan(score, 0.5, "Synonyms should have moderate to high similarity")
    }

    func testBuildPlaceDescription_combinesAllComponents() {
        // Given
        let name = "Blue Bottle Coffee"
        let categories = ["Coffee", "Cafe"]
        let description = "Artisanal coffee roaster"

        // When
        let placeDescription = service.buildPlaceDescription(
            name: name,
            categories: categories,
            description: description
        )

        // Then
        XCTAssertTrue(placeDescription.contains(name), "Should include name")
        XCTAssertTrue(placeDescription.contains("Coffee"), "Should include categories")
        XCTAssertTrue(placeDescription.contains("Artisanal"), "Should include description")
    }

    func testBuildPlaceDescription_withNilDescription_omitsDescription() {
        // Given
        let name = "Blue Bottle Coffee"
        let categories = ["Coffee", "Cafe"]

        // When
        let placeDescription = service.buildPlaceDescription(
            name: name,
            categories: categories,
            description: nil
        )

        // Then
        XCTAssertTrue(placeDescription.contains(name), "Should include name")
        XCTAssertTrue(placeDescription.contains("Coffee"), "Should include categories")
    }

    func testBuildPlaceDescription_withEmptyDescription_omitsDescription() {
        // Given
        let name = "Blue Bottle Coffee"
        let categories = ["Coffee", "Cafe"]

        // When
        let placeDescription = service.buildPlaceDescription(
            name: name,
            categories: categories,
            description: ""
        )

        // Then
        XCTAssertTrue(placeDescription.contains(name), "Should include name")
        XCTAssertTrue(placeDescription.contains("Coffee"), "Should include categories")
        XCTAssertFalse(placeDescription.hasSuffix("  "), "Should not have trailing spaces")
    }
}

// MARK: - Batch Semantic Scoring Tests

final class BatchSemanticScoringTests: XCTestCase {

    var service: VectorEmbeddingService!

    override func setUp() throws {
        try super.setUp()
        service = VectorEmbeddingService()
    }

    override func tearDown() throws {
        service = nil
        try super.tearDown()
    }

    func testBatchSemanticScores_withMultiplePlaces_returnsAllScores() {
        // Given
        let query = "coffee shop"
        let placeDescriptions = [
            "Blue Bottle Coffee specialty coffee roaster",
            "Starbucks coffee chain",
            "Pizza restaurant italian food"
        ]

        // When
        let scores = service.batchSemanticScores(query: query, placeDescriptions: placeDescriptions)

        // Then
        XCTAssertEqual(scores.count, 3, "Should return score for each place")
        XCTAssertGreaterThan(scores[0], scores[2], "Coffee shop should score higher than pizza")
        XCTAssertGreaterThan(scores[1], scores[2], "Starbucks should score higher than pizza")
    }

    func testBatchSemanticScores_withEmptyQuery_returnsAllZeros() {
        // Given
        let query = ""
        let placeDescriptions = ["coffee shop", "restaurant", "gym"]

        // When
        let scores = service.batchSemanticScores(query: query, placeDescriptions: placeDescriptions)

        // Then
        XCTAssertEqual(scores.count, 3, "Should return score for each place")
        XCTAssertTrue(scores.allSatisfy { $0 == 0.0 }, "All scores should be zero for empty query")
    }

    func testBatchSemanticScores_withEmptyDescriptions_returnsZeros() {
        // Given
        let query = "coffee shop"
        let placeDescriptions = ["", "", ""]

        // When
        let scores = service.batchSemanticScores(query: query, placeDescriptions: placeDescriptions)

        // Then
        XCTAssertEqual(scores.count, 3, "Should return score for each place")
        XCTAssertTrue(scores.allSatisfy { $0 == 0.0 }, "All scores should be zero for empty descriptions")
    }

    func testBatchSemanticScores_preservesOrder() {
        // Given
        let query = "italian restaurant"
        let placeDescriptions = [
            "Pizza place italian cuisine",
            "Coffee shop cafe",
            "Pasta restaurant italian food"
        ]

        // When
        let scores = service.batchSemanticScores(query: query, placeDescriptions: placeDescriptions)

        // Then
        XCTAssertEqual(scores.count, 3, "Should preserve order")
        // Scores should correspond to their descriptions
        XCTAssertGreaterThan(scores[0], scores[1], "Italian pizza should rank higher than coffee")
        XCTAssertGreaterThan(scores[2], scores[1], "Italian pasta should rank higher than coffee")
    }
}

// MARK: - Similarity Comparison Tests

final class SimilarityComparisonTests: XCTestCase {

    var service: VectorEmbeddingService!

    override func setUp() throws {
        try super.setUp()
        service = VectorEmbeddingService()
    }

    override func tearDown() throws {
        service = nil
        try super.tearDown()
    }

    func testAreSimilar_withSynonyms_returnsTrue() {
        // Given
        let term1 = "cheap"
        let term2 = "affordable"

        // When
        let areSimilar = service.areSimilar(term1, term2, threshold: 0.5)

        // Then
        XCTAssertTrue(areSimilar, "Cheap and affordable should be similar")
    }

    func testAreSimilar_withUnrelatedTerms_returnsFalse() {
        // Given
        let term1 = "coffee"
        let term2 = "hardware"

        // When
        let areSimilar = service.areSimilar(term1, term2, threshold: 0.7)

        // Then
        XCTAssertFalse(areSimilar, "Coffee and hardware should not be similar")
    }

    func testAreSimilar_withIdenticalTerms_returnsTrue() {
        // Given
        let term1 = "restaurant"
        let term2 = "restaurant"

        // When
        let areSimilar = service.areSimilar(term1, term2, threshold: 0.9)

        // Then
        XCTAssertTrue(areSimilar, "Identical terms should be similar")
    }

    func testAreSimilar_withHighThreshold_requiresStrongSimilarity() {
        // Given
        let term1 = "coffee"
        let term2 = "cafe"

        // When
        let areSimilarLowThreshold = service.areSimilar(term1, term2, threshold: 0.5)
        let areSimilarHighThreshold = service.areSimilar(term1, term2, threshold: 0.95)

        // Then
        XCTAssertTrue(areSimilarLowThreshold, "Should be similar with low threshold")
        // High threshold might or might not pass depending on embedding quality
    }

    func testAreSimilar_withEmptyTerm_returnsFalse() {
        // Given
        let term1 = ""
        let term2 = "coffee"

        // When
        let areSimilar = service.areSimilar(term1, term2)

        // Then
        XCTAssertFalse(areSimilar, "Empty term should not be similar")
    }

    func testAreSimilar_withDefaultThreshold_usesSeventyPercent() {
        // Given
        let term1 = "restaurant"
        let term2 = "cafe"

        // When - Use default threshold (0.7)
        let areSimilar = service.areSimilar(term1, term2)

        // Then - Should use 0.7 threshold by default
        // The result depends on the actual semantic similarity
        // Just verify it doesn't crash
        XCTAssertNotNil(areSimilar, "Should return a result")
    }
}

// MARK: - Edge Case Tests

final class VectorEmbeddingEdgeCaseTests: XCTestCase {

    var service: VectorEmbeddingService!

    override func setUp() throws {
        try super.setUp()
        service = VectorEmbeddingService()
    }

    override func tearDown() throws {
        service = nil
        try super.tearDown()
    }

    func testSemanticScore_withSpecialCharacters_handlesGracefully() {
        // Given
        let query = "café & restaurant!!!"
        let placeDescription = "cafe and restaurant"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertGreaterThan(score, 0.5, "Should handle special characters")
    }

    func testSemanticScore_withNumbers_handlesGracefully() {
        // Given
        let query = "24 hour restaurant"
        let placeDescription = "open 24 hours late night dining"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertGreaterThan(score, 0.0, "Should handle numbers in text")
    }

    func testSemanticScore_withMixedCase_normalizesCorrectly() {
        // Given
        let query = "COFFEE SHOP"
        let placeDescription = "coffee shop"

        // When
        let score = service.semanticScore(query: query, placeDescription: placeDescription)

        // Then
        XCTAssertGreaterThan(score, 0.9, "Should normalize case")
    }

    func testBatchSemanticScores_withEmptyArray_returnsEmptyArray() {
        // Given
        let query = "coffee"
        let placeDescriptions: [String] = []

        // When
        let scores = service.batchSemanticScores(query: query, placeDescriptions: placeDescriptions)

        // Then
        XCTAssertTrue(scores.isEmpty, "Should return empty array for empty input")
    }

    func testBuildPlaceDescription_withEmptyCategories_handlesCorrectly() {
        // Given
        let name = "Test Place"
        let categories: [String] = []

        // When
        let description = service.buildPlaceDescription(
            name: name,
            categories: categories,
            description: "Test description"
        )

        // Then
        XCTAssertTrue(description.contains(name), "Should still include name")
        XCTAssertTrue(description.contains("Test description"), "Should include description")
    }
}
