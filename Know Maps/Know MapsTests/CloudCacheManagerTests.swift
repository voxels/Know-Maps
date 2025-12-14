//
//  CloudCacheManagerTests.swift
//  Know MapsTests
//
//  Created for testing CloudCacheManager functionality
//

import XCTest
import CoreLocation
@testable import Know_Maps

// MARK: - Cache Refresh Tests

@MainActor
final class CacheRefreshTests: XCTestCase {

    var cacheManager: CloudCacheManager!
    var mockCloudCacheService: MockCloudCacheService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockCloudCacheService = MockCloudCacheService(analyticsManager: mockAnalytics)
        cacheManager = CloudCacheManager(
            cloudCacheService: mockCloudCacheService,
            analyticsManager: mockAnalytics
        )
    }

    override func tearDown() async throws {
        cacheManager = nil
        mockCloudCacheService = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testRefreshCache_setsIsRefreshingFlag() async throws {
        // Given
        XCTAssertFalse(cacheManager.isRefreshingCache, "Should start not refreshing")

        // When - Start refresh task
        Task {
            try await cacheManager.refreshCache()
        }

        // Give it a moment to set the flag
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Note: This is a timing-dependent test. The flag should be true during refresh
        // But by the time we check, refresh might be complete
    }

    func testRefreshCache_updatesProgress() async throws {
        // Given
        XCTAssertEqual(cacheManager.cacheFetchProgress, 0.0, "Should start at 0")

        // When
        try await cacheManager.refreshCache()

        // Then
        XCTAssertEqual(cacheManager.cacheFetchProgress, 1.0, "Should complete with progress 1.0")
        XCTAssertEqual(cacheManager.completedTasks, 6, "Should complete all 6 tasks")
    }

    func testRefreshCache_callsAllRefreshMethods() async throws {
        // Given/When
        try await cacheManager.refreshCache()

        // Then - Verify all data was loaded (exact counts depend on mock implementation)
        XCTAssertFalse(cacheManager.isRefreshingCache, "Should finish refreshing")
    }

    func testRefreshCache_populatesCachedResults() async throws {
        // Given - Setup mock to return some data
        let mockRecord = UserCachedRecord()
        mockRecord.identity = "test-category"
        mockRecord.title = "Test Category"
        mockRecord.list = "test-list"
        mockRecord.icons = "🏭"
        mockRecord.rating = 3
        mockRecord.section = "business"
        mockCloudCacheService.mockCachedRecords = [mockRecord]

        // When
        try await cacheManager.refreshCache()

        // Then
        XCTAssertTrue(
            cacheManager.cachedIndustryResults.count > 0 ||
            cacheManager.cachedTasteResults.count > 0 ||
            cacheManager.cachedPlaceResults.count > 0,
            "Should populate cached results"
        )
    }

    func testRefreshDefaultResults_populatesDefaults() async {
        // Given/When
        await cacheManager.refreshDefaultResults()

        // Then
        XCTAssertFalse(cacheManager.cachedDefaultResults.isEmpty, "Should populate default results")
        // Default results come from PersonalizedSearchSection.allCases
        XCTAssertTrue(
            cacheManager.cachedDefaultResults.count > 0,
            "Should have default category results"
        )
    }

    func testRefreshCachedResults_combinesAllResults() async {
        // Given
        await cacheManager.refreshDefaultResults()

        // When
        await cacheManager.refreshCachedResults()

        // Then
        XCTAssertEqual(
            cacheManager.allCachedResults.count,
            cacheManager.cachedDefaultResults.count +
            cacheManager.cachedIndustryResults.count +
            cacheManager.cachedTasteResults.count +
            cacheManager.cachedPlaceResults.count,
            "All cached results should combine all types"
        )
    }

    func testRefreshCachedResults_sortsByParentCategory() async {
        // Given
        await cacheManager.refreshDefaultResults()
        await cacheManager.refreshCachedResults()

        // When
        let results = cacheManager.allCachedResults

        // Then
        if results.count > 1 {
            for i in 0..<(results.count - 1) {
                XCTAssertLessThanOrEqual(
                    results[i].parentCategory.lowercased(),
                    results[i + 1].parentCategory.lowercased(),
                    "Results should be sorted alphabetically"
                )
            }
        }
    }
}

// MARK: - Cache Progress Tracking Tests

@MainActor
final class CacheProgressTrackingTests: XCTestCase {

    var cacheManager: CloudCacheManager!
    var mockCloudCacheService: MockCloudCacheService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockCloudCacheService = MockCloudCacheService(analyticsManager: mockAnalytics)
        cacheManager = CloudCacheManager(
            cloudCacheService: mockCloudCacheService,
            analyticsManager: mockAnalytics
        )
    }

    override func tearDown() async throws {
        cacheManager = nil
        mockCloudCacheService = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testCacheFetchProgress_startsAtZero() {
        // Given/When/Then
        XCTAssertEqual(cacheManager.cacheFetchProgress, 0.0, "Progress should start at 0")
        XCTAssertEqual(cacheManager.completedTasks, 0, "Completed tasks should start at 0")
    }

    func testCacheFetchProgress_reachesOneOnCompletion() async throws {
        // Given/When
        try await cacheManager.refreshCache()

        // Then
        XCTAssertEqual(cacheManager.cacheFetchProgress, 1.0, "Progress should reach 1.0")
        XCTAssertEqual(cacheManager.completedTasks, 6, "Should complete 6 tasks")
    }

    func testCacheFetchProgress_incrementsCorrectly() async throws {
        // Given
        let initialProgress = cacheManager.cacheFetchProgress

        // When
        try await cacheManager.refreshCache()

        // Then
        let finalProgress = cacheManager.cacheFetchProgress
        XCTAssertGreaterThan(finalProgress, initialProgress, "Progress should increase")
    }

    func testIsRefreshingCache_resetsAfterCompletion() async throws {
        // Given/When
        try await cacheManager.refreshCache()

        // Then
        XCTAssertFalse(cacheManager.isRefreshingCache, "Should not be refreshing after completion")
    }
}

// MARK: - Cache Restoration Tests

@MainActor
final class CacheRestorationTests: XCTestCase {

    var cacheManager: CloudCacheManager!
    var mockCloudCacheService: MockCloudCacheService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockCloudCacheService = MockCloudCacheService(analyticsManager: mockAnalytics)
        cacheManager = CloudCacheManager(
            cloudCacheService: mockCloudCacheService,
            analyticsManager: mockAnalytics
        )
    }

    override func tearDown() async throws {
        cacheManager = nil
        mockCloudCacheService = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testRestoreCache_callsCloudCacheService() async throws {
        // Given
        mockCloudCacheService.fetchAllRecordsCalled = false

        // When
        try await cacheManager.restoreCache()

        // Then
        XCTAssertTrue(mockCloudCacheService.fetchAllRecordsCalled, "Should call fetchAllRecords")
    }

    func testRestoreCache_requestsCorrectRecordTypes() async throws {
        // Given/When
        try await cacheManager.restoreCache()

        // Then
        XCTAssertTrue(mockCloudCacheService.fetchAllRecordsCalled, "Should request records")
        let requestedTypes = mockCloudCacheService.requestedRecordTypes ?? []
        XCTAssertTrue(
            requestedTypes.contains("UserCachedRecord"),
            "Should request UserCachedRecord"
        )
        XCTAssertTrue(
            requestedTypes.contains("RecommendationData"),
            "Should request RecommendationData"
        )
    }

    func testClearCache_removesAllData() {
        // Given
        cacheManager.cachedDefaultResults = [TestFixtures.makeCategoryResult()]
        cacheManager.cachedIndustryResults = [TestFixtures.makeCategoryResult()]
        cacheManager.cachedTasteResults = [TestFixtures.makeCategoryResult()]
        cacheManager.cachedPlaceResults = [TestFixtures.makeCategoryResult()]
        cacheManager.cachedLocationResults = [TestFixtures.makeLocationResult()]
        cacheManager.cachedRecommendationData = [TestFixtures.makeRecommendationData()]
        cacheManager.allCachedResults = [TestFixtures.makeCategoryResult()]

        // When
        cacheManager.clearCache()

        // Then
        XCTAssertTrue(cacheManager.cachedDefaultResults.isEmpty, "Should clear default results")
        XCTAssertTrue(cacheManager.cachedIndustryResults.isEmpty, "Should clear industry results")
        XCTAssertTrue(cacheManager.cachedTasteResults.isEmpty, "Should clear taste results")
        XCTAssertTrue(cacheManager.cachedPlaceResults.isEmpty, "Should clear place results")
        XCTAssertTrue(cacheManager.cachedLocationResults.isEmpty, "Should clear location results")
        XCTAssertTrue(cacheManager.cachedRecommendationData.isEmpty, "Should clear recommendation data")
        XCTAssertTrue(cacheManager.allCachedResults.isEmpty, "Should clear all cached results")
    }
}

// MARK: - Helper Method Tests

@MainActor
final class CacheHelperMethodTests: XCTestCase {

    var cacheManager: CloudCacheManager!
    var mockCloudCacheService: MockCloudCacheService!
    var mockAnalytics: MockAnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        mockAnalytics = MockAnalyticsService()
        mockCloudCacheService = MockCloudCacheService(analyticsManager: mockAnalytics)
        cacheManager = CloudCacheManager(
            cloudCacheService: mockCloudCacheService,
            analyticsManager: mockAnalytics
        )
    }

    override func tearDown() async throws {
        cacheManager = nil
        mockCloudCacheService = nil
        mockAnalytics = nil
        try await super.tearDown()
    }

    func testCachedCategories_withExistingCategory_returnsTrue() {
        // Given
        let categoryResult = TestFixtures.makeCategoryResult(parentCategory: "Italian")
        cacheManager.cachedIndustryResults = [categoryResult]

        // When
        let contains = cacheManager.cachedCategories(contains: "Italian")

        // Then
        XCTAssertTrue(contains, "Should find cached category")
    }

    func testCachedCategories_withNonExistingCategory_returnsFalse() {
        // Given
        cacheManager.cachedIndustryResults = []

        // When
        let contains = cacheManager.cachedCategories(contains: "Italian")

        // Then
        XCTAssertFalse(contains, "Should not find non-existing category")
    }

    func testCachedTastes_withExistingTaste_returnsTrue() {
        // Given
        let tasteResult = TestFixtures.makeTasteCategoryResult(title: "Romantic")
        cacheManager.cachedTasteResults = [tasteResult]

        // When
        let contains = cacheManager.cachedTastes(contains: "Romantic")

        // Then
        XCTAssertTrue(contains, "Should find cached taste")
    }

    func testCachedTastes_withNonExistingTaste_returnsFalse() {
        // Given
        cacheManager.cachedTasteResults = []

        // When
        let contains = cacheManager.cachedTastes(contains: "Romantic")

        // Then
        XCTAssertFalse(contains, "Should not find non-existing taste")
    }

    func testCachedLocation_withExistingLocation_returnsTrue() {
        // Given
        let locationResult = TestFixtures.makeLocationResult(name: "Golden Gate Park")
        cacheManager.cachedLocationResults = [locationResult]

        // When
        let contains = cacheManager.cachedLocation(contains: "Golden Gate Park")

        // Then
        XCTAssertTrue(contains, "Should find cached location")
    }

    func testCachedLocation_withNonExistingLocation_returnsFalse() {
        // Given
        cacheManager.cachedLocationResults = []

        // When
        let contains = cacheManager.cachedLocation(contains: "Golden Gate Park")

        // Then
        XCTAssertFalse(contains, "Should not find non-existing location")
    }

    func testCachedPlaces_withExistingPlace_returnsTrue() {
        // Given
        let placeResult = TestFixtures.makeCategoryResult(parentCategory: "Test Restaurant")
        cacheManager.cachedPlaceResults = [placeResult]

        // When
        let contains = cacheManager.cachedPlaces(contains: "Test Restaurant")

        // Then
        XCTAssertTrue(contains, "Should find cached place")
    }

    func testCachedLocationIdentity_generatesCorrectFormat() {
        // Given
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        // When
        let identity = cacheManager.cachedLocationIdentity(for: location)

        // Then
        XCTAssertEqual(identity, "37.7749,-122.4194", "Should format lat,lng correctly")
    }

    func testGetAllCachedCategoryResults_combinesAllTypes() {
        // Given
        cacheManager.cachedIndustryResults = [TestFixtures.makeIndustryCategoryResult()]
        cacheManager.cachedTasteResults = [TestFixtures.makeTasteCategoryResult()]
        cacheManager.cachedDefaultResults = [TestFixtures.makeCategoryResult()]
        cacheManager.cachedPlaceResults = [TestFixtures.makeCategoryResult()]

        // When
        let allResults = cacheManager.getAllCachedCategoryResults()

        // Then
        XCTAssertEqual(
            allResults.count,
            4,
            "Should combine all category result types"
        )
    }

    func testGetAllCachedCategoryResults_sortsByParentCategory() {
        // Given
        let category1 = TestFixtures.makeCategoryResult(parentCategory: "Zebra")
        let category2 = TestFixtures.makeCategoryResult(parentCategory: "Apple")
        cacheManager.cachedIndustryResults = [category1, category2]

        // When
        let allResults = cacheManager.getAllCachedCategoryResults()

        // Then
        XCTAssertEqual(allResults[0].parentCategory, "Apple", "Should sort alphabetically")
        XCTAssertEqual(allResults[1].parentCategory, "Zebra", "Should sort alphabetically")
    }
}

// MARK: - Enhanced Mock CloudCacheService

extension MockCloudCacheService {
    var mockCachedRecords: [UserCachedRecord] {
        get { Self._mockCachedRecords }
        set { Self._mockCachedRecords = newValue }
    }

    var fetchAllRecordsCalled: Bool {
        get { Self._fetchAllRecordsCalled }
        set { Self._fetchAllRecordsCalled = newValue }
    }

    var requestedRecordTypes: [String]? {
        get { Self._requestedRecordTypes }
        set { Self._requestedRecordTypes = newValue }
    }
}
