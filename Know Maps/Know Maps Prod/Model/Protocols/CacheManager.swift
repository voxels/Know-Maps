//
//  CacheManager.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

public protocol CacheManager : Sendable {
    var cloudCacheService:CloudCacheService { get }
    var isRefreshingCache: Bool  { get }
    var cacheFetchProgress:Double { get }
    var completedTasks:Int { get }
    
    var cachedDefaultResults:[CategoryResult] { get }
    var cachedIndustryResults:[CategoryResult] { get }
    var cachedTasteResults:[CategoryResult] { get }
    var cachedPlaceResults:[CategoryResult] { get }
    var allCachedResults:[CategoryResult] { get }
    var cachedLocationResults:[LocationResult] { get }
    var cachedRecommendationData:[RecommendationData] { get }
    
    // Refresh the entire cache for different data types
    func refreshCache() async throws    
    func restoreCache() async throws
    
    // Remove all cached results
    func clearCache() async
    
    // Refresh individual categories of cached data
    func refreshCachedCategories() async
    func refreshCachedTastes() async
    func refreshCachedPlaces() async
    func refreshCachedLocations() async
    func refreshCachedRecommendationData() async
    
    // Fetch all saved results
    func getAllCachedCategoryResults() -> [CategoryResult]
    
    // Cached Records Methods
    func cachedCategories(contains category: String) -> Bool
    func cachedTastes(contains taste: String) -> Bool
    func cachedLocation(contains location: String) -> Bool
    func cachedPlaces(contains place: String) -> Bool
    func cachedLocationIdentity(for location: CLLocation) -> String
}
