# Phase 2 Unit Tests - Implementation Guide

This document describes the Phase 2 unit test implementation for Know Maps.

## Overview

Phase 2 completes the unit test infrastructure with comprehensive test coverage for the following services:

1. **AssistiveChatHostService** - Natural language query processing
2. **FoundationModelsIntentClassifier** - ML-based intent classification
3. **CloudCacheManager** - CloudKit cache management
4. **DefaultPlaceSearchService** - Foursquare API integration
5. **VectorEmbeddingService** - Semantic similarity scoring
6. **Network Integration** - MockURLProtocol-based network testing

## Test Files

### Core Service Tests

#### AssistiveChatHostServiceTests.swift
Tests for natural language query processing and intent determination:

- **AssistiveChatHostIntentDeterminationTests**: Intent classification logic
  - Override intent handling
  - Category, place, location, and taste query detection
  - Multi-entity query processing
  - Edge cases (empty queries, special characters)

- **AssistiveChatHostQueryParsingTests**: Query parsing and filtering
  - Tag extraction from queries
  - Price range detection (cheap, expensive, not expensive)
  - Open now detection
  - Location qualifier filtering
  - Query sanitization

- **AssistiveChatHostCategoryMappingTests**: Foursquare category taxonomy
  - Category code loading
  - Category matching for queries
  - Section classification
  - Taxonomy organization

- **AssistiveChatHostIntentManagementTests**: Intent history management
  - Intent parameter appending
  - Intent history reset
  - Intent creation from ChatResult
  - Delegate notifications

#### FoundationModelsIntentClassifierTests.swift
Tests for CoreML-based intent classification:

- **IntentClassificationTests**: Search type determination
  - Category intent (restaurants, coffee)
  - Taste intent (romantic, cozy)
  - Place intent (Golden Gate Bridge)
  - Location intent (near downtown)
  - Mixed intent (complex queries)
  - Edge cases (empty, very short, very long)

- **FeatureExtractionTests**: Feature/taste detection
  - Outdoor seating
  - WiFi availability
  - Live music
  - Family-friendly
  - Multiple tastes in one query

- **PriceRangeExtractionTests**: Price tier detection
  - Cheap (1-2)
  - Expensive (3-4)
  - Luxury (3-4)
  - Affordable (1-2)
  - Not expensive (1-3)
  - Range clamping

- **LocationExtractionTests**: Location keyword detection
  - "near", "around", "in", "at", "close to"
  - Location description extraction

- **UnifiedSearchIntentHelperTests**: Intent utilities
  - Complex query detection
  - Intent descriptions
  - Icon mapping

#### CloudCacheManagerTests.swift
Tests for CloudKit cache orchestration:

- **CacheRefreshTests**: Cache loading
  - Refresh flag management
  - Progress tracking
  - All refresh methods called
  - Default results population
  - Combined results sorting

- **CacheProgressTrackingTests**: Progress monitoring
  - Initial state (0.0 progress)
  - Completion state (1.0 progress)
  - Task counting (6 total tasks)
  - Progress increments

- **CacheRestorationTests**: Cache restore operations
  - CloudCacheService calls
  - Record type requests
  - Cache clearing

- **CacheHelperMethodTests**: Utility methods
  - Category/taste/location/place existence checks
  - Location identity generation
  - Combined results retrieval
  - Alphabetical sorting

#### DefaultPlaceSearchServiceTests.swift
Tests for Foursquare API integration:

- **PlaceSearchRequestBuildingTests**: Request construction
  - Basic intent to request conversion
  - Location (lat/lng) inclusion
  - Category parameters
  - Price range (min/max)
  - Radius filtering
  - Open now flag
  - Query text vs category handling
  - Whitespace trimming

- **TasteAutocompleteTests**: Taste pagination
  - Last fetched page tracking
  - Page increment on refresh

- **FSQUserRetrievalTests**: User identity management
  - FSQ user creation when missing

- **DetailIntentTests**: Place details fetching
  - Details fetch with place response
  - No fetch without place response
  - Related places async loading

- **RecommendedPlaceSearchRequestTests**: Personalized search
  - Request construction with intent

#### VectorEmbeddingServiceTests.swift
Tests for semantic similarity:

- **EmbeddingGenerationTests**: Similarity scoring
  - Identical strings (high score >0.9)
  - Similar concepts (moderate score)
  - Unrelated strings (low score)
  - Empty query/description (0.0)
  - Synonyms (moderate-high score)
  - Place description building

- **BatchSemanticScoringTests**: Batch operations
  - Multiple place scoring
  - Empty query handling
  - Empty descriptions handling
  - Order preservation

- **SimilarityComparisonTests**: Term comparison
  - Synonym detection
  - Unrelated term rejection
  - Identical term matching
  - Threshold tuning
  - Empty term handling
  - Default threshold (0.7)

- **VectorEmbeddingEdgeCaseTests**: Edge cases
  - Special characters
  - Numbers in text
  - Mixed case normalization
  - Empty arrays
  - Empty categories

### Infrastructure Tests

#### NetworkIntegrationTests.swift
Tests demonstrating MockURLProtocol usage:

- **NetworkIntegrationTests**: Network mocking patterns
  - Foursquare response mocking
  - Error handling verification
  - Queued response ordering
  - Query parameter validation
  - Network latency simulation
  - Request history tracking

- **CloudCacheIntegrationTests**: MockCloudCacheService usage
  - Grouped record filtering
  - Record storage
  - Rating updates
  - Record deletion
  - Fetch all records tracking
  - Mock session configuration

## Mock Infrastructure

### MockURLProtocol (Know MapsTests/Mocks/MockURLProtocol.swift)
Network request interceptor for deterministic testing:

**Features:**
- Response handler for custom logic
- Queued responses for sequential requests
- Queued errors for failure testing
- Request history tracking
- Network latency simulation
- Helper methods for JSON responses
- Request verification utilities

**Usage:**
```swift
// Configure response handler
MockURLProtocol.responseHandler = { request in
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, ...)
    let data = mockData
    return (response, data)
}

// Create mock session
let session = MockURLProtocol.makeMockSession()

// Make request (will be intercepted)
let (data, _) = try await session.data(from: url)
```

### MockCloudCacheService (Know MapsTests/TestFixtures.swift)
Full CloudCache protocol implementation:

**Features:**
- All CloudCache protocol methods implemented
- Internal mock data storage
- Call tracking for verification
- Record filtering by group
- Recommendation data management
- Mock FSQ identity/token
- Mock URLSession with MockURLProtocol

**Properties:**
- `mockCachedRecords`: Stored UserCachedRecord instances
- `fetchAllRecordsCalled`: Tracks fetchAllRecords calls
- `requestedRecordTypes`: Tracks requested record types
- `hasFsqAccess`: Always true for testing

### Existing Mocks
The following mocks were created in Phase 1:

- **MockAnalyticsService**: Segment analytics tracking
- **MockAssistiveChatHost**: Natural language processing
- **MockCacheManager**: Cache orchestration
- **MockLocationService**: Location services
- **MockPlaceSearchService**: Place search
- **MockRecommenderService**: Recommendation engine
- **MockResultIndexServiceV2**: Result indexing
- **MockInputValidationServiceV2**: Input validation

All mocks in `Know MapsTests/Mocks/` directory.

## Test Fixtures

### TestFixtures.swift
Centralized fixture factory for creating test data:

**Location Fixtures:**
- `makeLocation()`: CLLocation instances
- `makeLocationResult()`: LocationResult with name

**ChatResult Fixtures:**
- `makeChatResult()`: ChatResult with customizable fields
- `makePlaceSearchResponse()`: PlaceSearchResponse
- `makeRecommendedPlaceSearchResponse()`: Recommended results

**CategoryResult Fixtures:**
- `makeCategoryResult()`: CategoryResult with children
- `makeIndustryCategoryResult()`: Industry-specific categories
- `makeTasteCategoryResult()`: Taste/feature categories

**Intent Fixtures:**
- `makeAssistiveChatHostIntent()`: Full intent with all fields

**Data Fixtures:**
- `makeRecommendationData()`: Recommendation instances

**Service Fixtures:**
- `makeInputValidationService()`: Real validation service
- `makeMockInputValidationService()`: Mock with preset results
- `makeResultIndexService()`: Real indexing service
- `makeMockResultIndexService()`: Mock with preset results
- `makeModelController()`: DefaultModelController with mocks

## Running Tests

### Build Tests
```bash
xcodebuild build -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Run All Phase 2 Tests
```bash
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests
```

### Run Specific Test Class
```bash
# AssistiveChatHostService tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/AssistiveChatHostIntentDeterminationTests

# FoundationModels tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/IntentClassificationTests

# CloudCacheManager tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/CacheRefreshTests

# DefaultPlaceSearchService tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/PlaceSearchRequestBuildingTests

# VectorEmbeddingService tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/EmbeddingGenerationTests

# Network integration tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/NetworkIntegrationTests
```

### Run Single Test Method
```bash
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Know_MapsTests/AssistiveChatHostIntentDeterminationTests/testDetermineIntentEnhanced_withOverride_returnsOverrideIntent
```

## Test Coverage

### Current Coverage by Service

1. **AssistiveChatHostService**: ~35 tests
   - Intent determination: 8 tests
   - Query parsing: 11 tests
   - Category mapping: 6 tests
   - Intent management: 4 tests
   - Includes delegate mock

2. **FoundationModelsIntentClassifier**: ~40 tests
   - Intent classification: 11 tests
   - Feature extraction: 6 tests
   - Price range: 7 tests
   - Location extraction: 5 tests
   - Helper methods: 5 tests

3. **CloudCacheManager**: ~25 tests
   - Cache refresh: 8 tests
   - Progress tracking: 4 tests
   - Cache restoration: 3 tests
   - Helper methods: 10 tests

4. **DefaultPlaceSearchService**: ~20 tests
   - Request building: 9 tests
   - Taste autocomplete: 2 tests
   - FSQ user retrieval: 1 test
   - Detail intent: 2 tests
   - Recommended search: 1 test

5. **VectorEmbeddingService**: ~25 tests
   - Embedding generation: 9 tests
   - Batch scoring: 5 tests
   - Similarity comparison: 7 tests
   - Edge cases: 5 tests

6. **Network Integration**: ~7 tests
   - Network mocking examples
   - CloudCache integration examples

**Total Phase 2 Tests**: ~150+ test cases

## Architecture Notes

### MainActor Isolation
Most services are `@MainActor` bound, so tests must be marked with `@MainActor`:

```swift
@MainActor
final class MyServiceTests: XCTestCase {
    // Tests here
}
```

### Async Testing
All async operations use `async throws` pattern:

```swift
func testAsyncOperation() async throws {
    let result = try await service.performOperation()
    XCTAssertNotNil(result)
}
```

### Mock Reset Pattern
Always reset mocks in setUp/tearDown:

```swift
override func setUp() async throws {
    try await super.setUp()
    mockService = MockService()
    MockURLProtocol.reset()
}

override func tearDown() async throws {
    mockService = nil
    MockURLProtocol.reset()
    try await super.tearDown()
}
```

## Known Limitations

1. **Network-Dependent Tests**: Some tests in DefaultPlaceSearchService that fetch actual data are marked to handle network failures gracefully
2. **ML Model Tests**: Intent classifier tests verify structure but actual ML predictions may vary
3. **Timing Tests**: Progress tracking tests may be timing-sensitive
4. **Test Host**: Tests currently require building the main app target first

## Next Steps (Phase 3 - Future)

Potential areas for expansion:

1. **Integration Tests**: End-to-end workflows
2. **UI Tests**: SwiftUI view testing
3. **Performance Tests**: Measure.metrics for performance regression
4. **Snapshot Tests**: View snapshot testing
5. **CloudKit Tests**: Actual CloudKit container testing
6. **Accessibility Tests**: VoiceOver and accessibility testing

## Contributing

When adding new tests:

1. Place in appropriate test file by service
2. Use TestFixtures for consistent test data
3. Reset mocks in setUp/tearDown
4. Use descriptive test names: `test<Condition>_<Action>_<ExpectedResult>`
5. Add comments explaining complex setup
6. Use Given/When/Then structure for clarity
7. Verify tests pass before committing

## References

- **CLAUDE.md**: Project overview and architecture
- **TestFixtures.swift**: Fixture factory methods
- **MockURLProtocol.swift**: Network mocking guide
- **Existing Phase 1 Tests**: DefaultModelControllerTests.swift for patterns
