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

    @Published private var cachedCategoryRecords: [UserCachedRecord] = []
    @Published private var cachedTasteRecords: [UserCachedRecord] = []
    @Published private var cachedPlaceRecords: [UserCachedRecord] = []
    @Published private var cachedLocationRecords: [UserCachedRecord] = []

    // Cached Results
    @Published public var cachedDefaultResults = [CategoryResult]()
    @Published public var cachedIndustryResults = [CategoryResult]()
    @Published public var cachedTasteResults = [CategoryResult]()
    @Published public var cachedPlaceResults = [CategoryResult]()
    @Published public var allCachedResults = [CategoryResult]()
    @Published public var cachedLocationResults = [LocationResult]()
    
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
        let totalTasks = 5
        
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
            cachedCategoryRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Category")
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
            cachedTasteRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Taste")
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
            self.cachedPlaceRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Place")
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
            cachedLocationRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Location")
            let locationResults = savedLocationResults()
            await MainActor.run {
                cachedLocationResults = locationResults
            }
        }   catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    public func refreshCachedResults() async {
        let savedResults = getAllCachedResults()
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
    
    // MARK: Append Cached Data
    
    public func appendCachedLocation(record: UserCachedRecord) async {
        cachedLocationRecords.append(record)
        let locationResults = savedLocationResults()
        await MainActor.run {
            cachedLocationResults = locationResults
        }
    }
    
    public func appendCachedCategory(record: UserCachedRecord) async {
        cachedCategoryRecords.append(record)
        let categoricalResults = savedCategoricalResults()
        await MainActor.run {
            cachedIndustryResults = categoricalResults
        }
    }
    
    public func appendCachedTaste(record: UserCachedRecord) async {
        cachedTasteRecords.append(record)
        let tasteResults = savedTasteResults()
        await MainActor.run {
            cachedTasteResults = tasteResults
        }
    }
    
    
    public func appendCachedPlace(record: UserCachedRecord) async {
        cachedPlaceRecords.append(record)
        let placeResults = savedPlaceResults()
        await MainActor.run {
            cachedPlaceResults = placeResults
        }
    }
    
    // MARK: - Saved Results
    
    private func savedCategoricalResults() -> [CategoryResult] {
        return cachedCategoryRecords.map {
            let chatResults = [ChatResult(title: $0.title, list:$0.list, icon: $0.icons, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, placeResponse: nil, recommendedPlaceResponse: nil)]
            return CategoryResult(parentCategory: $0.title, list: $0.list, icon:$0.icons, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, categoricalChatResults: chatResults)
        }.sorted(by: {$0.parentCategory < $1.parentCategory})
    }
    
    private func savedTasteResults() -> [CategoryResult] {
        return cachedTasteRecords.map {
            let chatResults = [ChatResult(title: $0.title, list:$0.list, icon:$0.icons, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, placeResponse: nil, recommendedPlaceResponse: nil)]
            return CategoryResult(parentCategory: $0.title, list: $0.list, icon:$0.icons, section:PersonalizedSearchSection(rawValue:$0.section) ?? .none, categoricalChatResults: chatResults)
        }.sorted(by: {$0.parentCategory < $1.parentCategory})
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
                
                chatResults = [ChatResult(title: record.title, list: record.list, icon:record.icons, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, placeResponse: placeResponse, recommendedPlaceResponse: nil)]
                
                return CategoryResult(parentCategory:record.title, list: record.list, icon:record.icons, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, categoricalChatResults: chatResults)
            } else {
                chatResults = [ChatResult(title: record.title, list: record.list, icon: record.icons, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, placeResponse: nil, recommendedPlaceResponse: nil)]
            }
            return CategoryResult(parentCategory: record.title, list: record.list, icon: record.icons, section:PersonalizedSearchSection(rawValue:record.section) ?? .none, categoricalChatResults: chatResults)
        }.sorted(by: {$0.parentCategory < $1.parentCategory})
    }
    

    private func defaultResults() -> [CategoryResult] {
        PersonalizedSearchSection.allCases.filter({$0 != .location && $0 != .none && $0 != .trending})
            .map({$0.categoryResult()})
    }
    
    public func getAllCachedResults() -> [CategoryResult] {
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
