//
//  CloudCacheManager.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

public final class CloudCacheManager: CacheManager, ObservableObject {
    public let cloudCache: CloudCache
    private let analyticsManager:AnalyticsService
    @Published public var isRefreshingCache: Bool = false
    @Published public var cacheFetchProgress:Double = 0
    @Published public var completedTasks = 0

    private var cachedCategoryRecords: [UserCachedRecord] = []
    private var cachedTasteRecords: [UserCachedRecord] = []
    private var cachedPlaceRecords: [UserCachedRecord] = []
    private var cachedLocationRecords: [UserCachedRecord] = []

    // Cached Results
    public var cachedDefaultResults = [CategoryResult]()
    public var cachedIndustryResults = [CategoryResult]()
    public var cachedTasteResults = [CategoryResult]()
    public var cachedPlaceResults = [CategoryResult]()
    public var allCachedResults = [CategoryResult]()
    public var cachedLocationResults = [LocationResult]()
    public var cachedRecommendationData = [RecommendationData]()
    
    init(cloudCache: CloudCache, analyticsManager:AnalyticsService) {
        self.cloudCache = cloudCache
        self.analyticsManager = analyticsManager
    }
    
    // MARK: Refresh Cache
    
    public func refreshCache() async throws {
        await MainActor.run {
            isRefreshingCache = true
        }
        
        // Initialize progress variables
        let totalTasks = 6
        
        // Create a task that encapsulates the entire operation
        let operationTask = Task {
            // Use a throwing task group to manage tasks and handle cancellations
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Define tasks with progress updates
                
                group.addTask {
                    try Task.checkCancellation()
                    await self.refreshDefaultResults()
                    try Task.checkCancellation()
                    await MainActor.run { [self] in
                        self.completedTasks += 1
                        let progress = Double(self.completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask { [self] in
                    try Task.checkCancellation()
                    await self.refreshCachedCategories()
                    try Task.checkCancellation()
                    await MainActor.run { [self] in
                        self.completedTasks += 1
                        let progress = Double(self.completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask { [self] in
                    try Task.checkCancellation()
                    await self.refreshCachedTastes()
                    try Task.checkCancellation()
                    await MainActor.run { [self] in
                        self.completedTasks += 1
                        let progress = Double(self.completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask { [self] in
                    try Task.checkCancellation()
                    await self.refreshCachedPlaces()
                    try Task.checkCancellation()
                    await MainActor.run { [self] in
                        self.completedTasks += 1
                        let progress = Double(self.completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask { [self] in
                    try Task.checkCancellation()
                    await self.refreshCachedLocations()
                    try Task.checkCancellation()
                    await MainActor.run { [self] in
                        self.completedTasks += 1
                        let progress = Double(self.completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask { [self] in
                    try Task.checkCancellation()
                    await self.refreshCachedRecommendationData()
                    try Task.checkCancellation()
                    await MainActor.run { [self] in
                        self.completedTasks += 1
                        let progress = Double(self.completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                // Wait for all tasks to complete or handle cancellation
                try await group.waitForAll()
            }
            
            // Proceed with remaining tasks after the group tasks are done
            await refreshCachedResults()
        }
        
        try await operationTask.value
        
        await MainActor.run {
            isRefreshingCache = false
        }
    }
    
    public func refreshCachedCategories() async {
        do {
            let records =  try await cloudCache.fetchGroupedUserCachedRecords(for: "Category")
            await MainActor.run {
                cachedCategoryRecords = records
            }
            let categoryResults = savedCategoricalResults()
            await MainActor.run {
                cachedIndustryResults = categoryResults
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    
    public func refreshCachedTastes() async {
        do {
            let records =  try await cloudCache.fetchGroupedUserCachedRecords(for: "Taste")
            await MainActor.run {
                cachedTasteRecords = records
            }
            let tasteResults = savedTasteResults()
            await MainActor.run {
                cachedTasteResults = tasteResults
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func refreshCachedPlaces() async {
        do {
            let records = try await cloudCache.fetchGroupedUserCachedRecords(for: "Place")
            await MainActor.run {
                cachedPlaceRecords = records
            }
            let placeResults = savedPlaceResults()
            await MainActor.run {
                cachedPlaceResults = placeResults
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func refreshCachedLocations() async  {
        do {
            let records = try await cloudCache.fetchGroupedUserCachedRecords(for: "Location")
            await MainActor.run {
                cachedLocationRecords = records
            }
            let locationResults = savedLocationResults()
            await MainActor.run {
                cachedLocationResults = locationResults
            }
        }   catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func refreshCachedRecommendationData() async {
        do {
            let records = try await cloudCache.fetchRecomendationData()
            await MainActor.run {
                cachedRecommendationData = records
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func refreshCachedResults() async {
        let savedResults = getAllCachedCategoryResults()
        await MainActor.run {
            allCachedResults = savedResults
        }
    }
    
    
    public func refreshDefaultResults() async {
        let defaults = defaultResults()
        await MainActor.run {
            cachedDefaultResults = defaults
        }
    }
    
    @MainActor
    public func clearCache() {
        cachedPlaceResults.removeAll()
        cachedTasteResults.removeAll()
        cachedIndustryResults.removeAll()
        cachedLocationResults.removeAll()
    }
    
    
    // MARK: - Saved Results
    
    private func savedCategoricalResults() -> [CategoryResult] {
        return cachedCategoryRecords.map {
            let chatResults = [ChatResult(title: $0.title, list:$0.list, icon: $0.icons, rating: $0.rating, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, placeResponse: nil, recommendedPlaceResponse: nil)]
            return CategoryResult(parentCategory: $0.title, recordId: $0.recordId, list: $0.list, icon:$0.icons, rating: $0.rating, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, categoricalChatResults: chatResults)
        }.sorted(by: {$0.parentCategory.lowercased() < $1.parentCategory.lowercased()})
    }
    
    private func savedTasteResults() -> [CategoryResult] {
        return cachedTasteRecords.map {
            let chatResults = [ChatResult(title: $0.title, list:$0.list, icon:$0.icons, rating: $0.rating, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, placeResponse: nil, recommendedPlaceResponse: nil)]
            return CategoryResult(parentCategory: $0.title, recordId: $0.recordId, list: $0.list, icon:$0.icons, rating: $0.rating, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, categoricalChatResults: chatResults)
        }.sorted(by: {$0.parentCategory.lowercased() < $1.parentCategory.lowercased()})
    }
    
    private func savedPlaceResults() -> [CategoryResult] {
        return cachedPlaceRecords.map { record in
            var chatResults = [ChatResult]()
            if record.group == "Place" {
                let placeResponse = PlaceSearchResponse(
                    fsqID: record.identity,
                    name: "",
                    categories: [],
                    latitude: 0,
                    longitude: 0,
                    address: "",
                    addressExtended: "",
                    country: "",
                    dma: "",
                    formattedAddress: "",
                    locality: "",
                    postCode: "",
                    region: "",
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
                
                chatResults = [ChatResult(title: record.title, list: record.list, icon:record.icons, rating: record.rating, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, placeResponse: placeResponse, recommendedPlaceResponse: nil)]
                
                return CategoryResult(parentCategory:record.title, recordId: record.recordId, list: record.list, icon:record.icons, rating: record.rating, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, categoricalChatResults: chatResults)
            } else {
                chatResults = [ChatResult(title: record.title, list: record.list, icon: record.icons, rating: record.rating, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, placeResponse: nil, recommendedPlaceResponse: nil)]
            }
            return CategoryResult(parentCategory: record.title, recordId: record.recordId, list: record.list, icon: record.icons, rating: record.rating, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, categoricalChatResults: chatResults)
        }.sorted(by: {$0.parentCategory.lowercased() < $1.parentCategory.lowercased()})
    }
    

    private func defaultResults() -> [CategoryResult] {
        PersonalizedSearchSection.allCases.filter({$0 != .location && $0 != .none && $0 != .trending})
            .map({$0.categoryResult()})
    }
    
    public func getAllCachedCategoryResults() -> [CategoryResult] {
        var results = cachedIndustryResults + cachedTasteResults + cachedPlaceResults + cachedDefaultResults
        
        results.sort { $0.parentCategory.lowercased() < $1.parentCategory.lowercased() }
        return results
    }
    
    private func savedLocationResults() -> [LocationResult] {
        return cachedLocationRecords.compactMap { record in
            let components = record.identity.split(separator: ",")
            if components.count == 2,
               let latitude = Double(components[0]),
               let longitude = Double(components[1]) {
                return LocationResult(locationName: record.title, location: CLLocation(latitude: latitude, longitude: longitude))
            }
            return nil
        }
    }
   
    // MARK: Cached Records Methods
    
    public func cachedCategories(contains category: String) -> Bool {
        return cachedCategoryRecords.contains { $0.identity == category }
    }
    
    public func cachedTastes(contains taste: String) -> Bool {
        return cachedTasteRecords.contains { $0.identity == taste }
    }
    
    public func cachedLocation(contains location: String) -> Bool {
        return cachedLocationResults.contains { $0.locationName == location }
    }
    
    public func cachedPlaces(contains place:String) -> Bool {
        return cachedPlaceResults.contains { $0.parentCategory == place }
    }
    
    public func cachedLocationIdentity(for location: CLLocation) -> String {
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
        
    // MARK: Fetch Cached Results by Group and Identity
    
    public func cachedResults(for group: String, identity: String) -> [UserCachedRecord]? {
        let allCachedRecords: [UserCachedRecord]? = {
            switch group {
            case "Category":
                return cachedCategoryRecords
            case "Taste":
                return cachedTasteRecords
            case "Location":
                return cachedLocationRecords
            case "Place":
                return cachedPlaceRecords
            default:
                return nil
            }
        }()
        
        return allCachedRecords?.filter { $0.group == group && $0.identity == identity }
    }
    
}
