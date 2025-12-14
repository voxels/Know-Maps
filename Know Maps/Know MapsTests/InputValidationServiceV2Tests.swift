//
//  InputValidationServiceV2Tests.swift
//  Know MapsTests
//
//  Comprehensive tests for InputValidationServiceV2
//

import XCTest
@testable import Know_Maps

@MainActor
final class InputValidationServiceV2Tests: XCTestCase {

    var service: DefaultInputValidationServiceV2!

    override func setUp() async throws {
        service = TestFixtures.makeInputValidationService()
    }

    override func tearDown() async throws {
        service = nil
    }

    // MARK: - Whitespace Normalization Tests (3 tests)

    func testSanitize_withExtraWhitespace_normalizesSpaces() {
        // Given
        let query = "  test   query  "

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "test query")
    }

    func testSanitize_withNewlinesAndTabs_replacesWithSpaces() {
        // Given
        let query = "test\nquery\twith\rmixed"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "test query with mixed")
    }

    func testSanitize_withMultipleSpaces_collapsesToSingle() {
        // Given
        let query = "test     multiple      spaces"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "test multiple spaces")
    }

    // MARK: - Control Character Removal Tests (2 tests)

    func testSanitize_withControlCharacters_removesControlChars() {
        // Given
        let query = "test\u{0000}query\u{001F}data"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "testquerydata")
    }

    func testSanitize_withDeleteCharacter_removesDeleteChar() {
        // Given
        let query = "test\u{007F}query"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "testquery")
    }

    // MARK: - Delimiter Artifact Cleanup Tests (3 tests)

    func testSanitize_withEqualCommaArtifact_removesArtifact() {
        // Given
        let query = "query = , value"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "query=value")
    }

    func testSanitize_withDoubleCommas_replacesWithSingle() {
        // Given
        let query = "term1, , term2"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "term1,term2")
    }

    func testSanitize_withSpacesAroundDelimiters_removesSpaces() {
        // Given
        let query = "key = value , another"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "key=value,another")
    }

    // MARK: - Empty/Nil Handling Tests (2 tests)

    func testSanitize_withEmptyString_returnsEmpty() {
        // Given
        let query = ""

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "")
    }

    func testSanitize_withOnlyWhitespace_returnsEmpty() {
        // Given
        let query = "   \n\t\r   "

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "")
    }

    // MARK: - Unicode Edge Cases Tests (2 tests)

    func testSanitize_withUnicodeCharacters_preservesUnicode() {
        // Given
        let query = "café 东京 🍕"

        // When
        let result = service.sanitize(query: query)

        // Then
        XCTAssertEqual(result, "café 东京 🍕")
    }

    func testSanitize_withLongQuery_truncatesToMaxLength() {
        // Given
        let longQuery = String(repeating: "a", count: 250)

        // When
        let result = service.sanitize(query: longQuery)

        // Then
        XCTAssertEqual(result.count, 200)
        XCTAssertTrue(result.allSatisfy { $0 == "a" })
    }

    // MARK: - Search Term Joining Tests (3 tests)

    func testJoin_withValidTerms_returnsCommaSeparated() {
        // Given
        let terms = ["coffee", "shops", "nearby"]

        // When
        let result = service.join(searchTerms: terms)

        // Then
        XCTAssertEqual(result, "coffee,shops,nearby")
    }

    func testJoin_withWhitespace_trimsAndJoins() {
        // Given
        let terms = ["  coffee  ", "  shops  ", "  nearby  "]

        // When
        let result = service.join(searchTerms: terms)

        // Then
        XCTAssertEqual(result, "coffee,shops,nearby")
    }

    func testJoin_withEmptyTerms_filtersOut() {
        // Given
        let terms = ["coffee", "", "  ", "shops"]

        // When
        let result = service.join(searchTerms: terms)

        // Then
        XCTAssertEqual(result, "coffee,shops")
    }

    // MARK: - Intent Validation Tests (bonus tests for completeness)

    func testValidate_withValidIntent_returnsTrue() {
        // Given
        let intent = TestFixtures.makeAssistiveChatHostIntent(
            caption: "test query",
            selectedDestinationLocation: TestFixtures.makeLocationResult(name: "San Francisco")
        )

        // When
        let result = service.validate(intent: intent)

        // Then
        XCTAssertTrue(result)
    }

    func testValidate_withEmptyCaption_returnsFalse() {
        // Given
        let intent = TestFixtures.makeAssistiveChatHostIntent(
            caption: "   ",
            selectedDestinationLocation: TestFixtures.makeLocationResult()
        )

        // When
        let result = service.validate(intent: intent)

        // Then
        XCTAssertFalse(result)
    }
}
