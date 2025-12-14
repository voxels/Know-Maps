//
//  MockCacheManager.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
import CoreLocation
@testable import Know_Maps

@MainActor
final class MockCacheManager: CacheManager, @unchecked Sendable {
    var analyticsManager: AnalyticsService
    var cloudCacheService: CloudCacheService
    var isRefreshingCache: Bool = false
    var cacheFetchProgress: Double = 0.0
    var completedTasks: Int = 0
    
    // Configurable cached data
    var cachedDefaultResults: [CategoryResult] = []
    var cachedIndustryResults: [CategoryResult] = []
    var cachedTasteResults: [CategoryResult] = []
    var cachedPlaceResults: [CategoryResult] = []
    var allCachedResults: [CategoryResult] = []
    var cachedLocationResults: [LocationResult] = []
    var cachedRecommendationData: [RecommendationData] = []
    
    // Track method calls
    var refreshCacheCalled: Bool = false
    var restoreCacheCalled: Bool = false
    var clearCacheCalled: Bool = false
    
    init(cloudCacheService: CloudCacheService, analyticsManager:AnalyticsService) {
        self.cloudCacheService = cloudCacheService
        self.analyticsManager = analyticsManager
    }
    
    func refreshCache() async throws {
        refreshCacheCalled = true
    }
    
    func restoreCache() async throws {
        restoreCacheCalled = true
    }
    
    func clearCache() async {
        clearCacheCalled = true
        cachedDefaultResults.removeAll()
        cachedIndustryResults.removeAll()
        cachedTasteResults.removeAll()
        cachedPlaceResults.removeAll()
        allCachedResults.removeAll()
        cachedLocationResults.removeAll()
        cachedRecommendationData.removeAll()
    }
    
    func refreshCachedCategories() async {
        // No-op for testing
    }
    
    func refreshCachedTastes() async {
        // No-op for testing
    }
    
    func refreshCachedPlaces() async {
        // No-op for testing
    }
    
    func refreshCachedLocations() async {
        // No-op for testing
    }
    
    func refreshCachedRecommendationData() async {
        // No-op for testing
    }
    
    func getAllCachedCategoryResults() -> [CategoryResult] {
        return allCachedResults
    }
    
    func cachedCategories(contains category: String) -> Bool {
        return cachedIndustryResults.contains { $0.parentCategory == category }
    }
    
    func cachedTastes(contains taste: String) -> Bool {
        return cachedTasteResults.contains { $0.parentCategory == taste }
    }
    
    func cachedLocation(contains location: String) -> Bool {
        return cachedLocationResults.contains { $0.locationName == location }
    }
    
    func cachedPlaces(contains place: String) -> Bool {
        return cachedPlaceResults.contains { $0.parentCategory == place }
    }
    
    func cachedLocationIdentity(for location: CLLocation) -> String {
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
}
