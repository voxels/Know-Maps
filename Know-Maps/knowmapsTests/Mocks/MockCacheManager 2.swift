//
//  MockCacheManager.swift
//  knowmapsTests
//

import Foundation
import CoreLocation
import SwiftData
@testable import Know_Maps

@MainActor
public final class MockCacheManager: CacheManager {
    public var cloudCacheService: CloudCacheService
    public var proactiveCacheService: ProactiveCacheService?
    public var analyticsManager: AnalyticsService
    
    public var isRefreshingCache: Bool = false
    public var cacheFetchProgress: Double = 0
    public var completedTasks: Int = 0
    
    public var cachedDefaultResults: [CategoryResult] = []
    public var cachedIndustryResults: [CategoryResult] = []
    public var cachedTasteResults: [CategoryResult] = []
    public var cachedPlaceResults: [CategoryResult] = []
    public var allCachedResults: [CategoryResult] = []
    public var cachedLocationResults: [LocationResult] = []
    public var cachedRecommendationData: [RecommendationData] = []
    public var allCachedTastes: [UserCachedRecord] = []
    
    public init(analyticsManager: AnalyticsService = MockAnalyticsService()) {
        self.analyticsManager = analyticsManager
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: UserCachedRecord.self, RecommendationData.self, configurations: config)
        self.cloudCacheService = CloudCacheService(analyticsManager: analyticsManager, modelContext: ModelContext(container))
    }
    
    public func refreshCache() async throws {}
    public func restoreCache() async throws {}
    public func clearCache() async {
        cachedDefaultResults.removeAll()
        cachedIndustryResults.removeAll()
        cachedTasteResults.removeAll()
        cachedPlaceResults.removeAll()
        cachedLocationResults.removeAll()
        cachedRecommendationData.removeAll()
        allCachedResults.removeAll()
    }
    
    public func refreshCachedCategories() async {}
    public func refreshCachedTastes() async {}
    public func refreshCachedPlaces() async {}
    public func refreshCachedLocations() async {}
    public func refreshCachedRecommendationData() async {}
    
    public func getAllCachedCategoryResults() -> [CategoryResult] { allCachedResults }
    
    public func cachedCategories(contains category: String) -> Bool { false }
    public func cachedTastes(contains taste: String) -> Bool { false }
    public func cachedLocation(contains location: String) -> Bool { false }
    public func cachedPlaces(contains place: String) -> Bool { false }
    public func cachedLocationIdentity(for location: CLLocation) -> String { "" }
}
