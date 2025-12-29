//
//  CloudCacheManager.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation
import SwiftData


@Observable
public final class CloudCacheManager: @preconcurrency CacheManager {
    
    public let cloudCacheService: CloudCacheService
    public var proactiveCacheService: ProactiveCacheService?
    public weak var placeSearchService: (any PlaceSearchRequestService)?
    public let analyticsManager:AnalyticsService
    @MainActor public var isRefreshingCache: Bool = false
    @MainActor public var cacheFetchProgress: Double = 0
    @MainActor public var completedTasks = 0

    // Cached Results
    @MainActor public var cachedDefaultResults = [CategoryResult]()
    @MainActor public var cachedIndustryResults = [CategoryResult]()
    @MainActor public var cachedTasteResults = [CategoryResult]()
    @MainActor public var cachedPlaceResults = [CategoryResult]()
    @MainActor public var allCachedResults = [CategoryResult]()
    @MainActor public var cachedLocationResults = [LocationResult]()
    @MainActor public var cachedRecommendationData = [RecommendationData]()
    @MainActor public var allCachedTastes = [UserCachedRecord]()

    public init(cloudCacheService:CloudCacheService, proactiveCacheService: ProactiveCacheService? = nil, analyticsManager: AnalyticsService) { 
        self.cloudCacheService = cloudCacheService
        self.proactiveCacheService = proactiveCacheService
        self.analyticsManager = analyticsManager
    }

    // MARK: Refresh Cache

    public func refreshCache() async throws {
        await MainActor.run {
            isRefreshingCache = true
            completedTasks = 0
            cacheFetchProgress = 0
        }

        let totalTasks = 6

        // Fetch data from local store first and update UI
        await refreshDefaultResults()
        await updateProgress(for: 1, totalTasks: totalTasks)

        await refreshCachedCategories()
        await updateProgress(for: 2, totalTasks: totalTasks)

        await refreshCachedTastes()
        await updateProgress(for: 3, totalTasks: totalTasks)

        await refreshCachedPlaces()
        await updateProgress(for: 4, totalTasks: totalTasks)

        await refreshCachedLocations()
        await updateProgress(for: 5, totalTasks: totalTasks)

        // Update allCachedResults
        await refreshCachedResults()

        // Proactively cache favorites to ensure zero-latency selection
        await proactivelyCacheFavorites()

        // Update isRefreshingCache
        await MainActor.run {
            isRefreshingCache = false
        }
    }

    // Helper function to update progress and completed tasks
    private func updateProgress(for taskNumber: Int, totalTasks: Int) async {
        await MainActor.run {
            completedTasks = taskNumber
            cacheFetchProgress = Double(completedTasks) / Double(totalTasks)
        }
    }
    
    @MainActor
    public func refreshCachedCategories() async {
        do {
            let records = try await cloudCacheService.fetchGroupedUserCachedRecords(for: "Category")
            let results = self.createCategoryResults(from: records)
            await MainActor.run {
                self.cachedIndustryResults = results
            }
        } catch {
            cloudCacheService.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    @MainActor
    public func refreshCachedTastes() async {
        do {
            let records = try await cloudCacheService.fetchGroupedUserCachedRecords(for: "Taste")
            let results = self.createCategoryResults(from: records)
            await MainActor.run {
                self.cachedTasteResults = results
                self.allCachedTastes = records
            }
        } catch {
            cloudCacheService.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    @MainActor
    public func refreshCachedPlaces() async {
        do {
            let records = try await cloudCacheService.fetchGroupedUserCachedRecords(for: "Place")
            let results = self.createPlaceResults(from: records)
            await MainActor.run {
                self.cachedPlaceResults = results
            }
        } catch {
            cloudCacheService.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    @MainActor
    public func refreshCachedLocations() async {
        do {
            let records = try await cloudCacheService.fetchGroupedUserCachedRecords(for: "Location")
            let locationResults = self.createLocationResults(from: records)
            await MainActor.run {
                self.cachedLocationResults = locationResults
            }
        } catch {
            cloudCacheService.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    @MainActor
    public func refreshCachedRecommendationData() async {
        do {
            let records = try await cloudCacheService.fetchRecommendationData()
            await MainActor.run {
                self.cachedRecommendationData = records
            }
        } catch {
            cloudCacheService.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    @MainActor
    public func refreshCachedResults() async {
        let allCachedCategoryResults = self.getAllCachedCategoryResults()
        await MainActor.run {
            self.allCachedResults = allCachedCategoryResults
        }
    }

    public func refreshDefaultResults() async {
        let results = self.defaultResults()
        await MainActor.run {
            self.cachedDefaultResults = results
        }
    }
    
    public func restoreCache() async throws {
        try await cloudCacheService.fetchAllRecords(recordTypes: ["UserCachedRecord", "RecommendationData"])
    }

    @MainActor
    public func clearCache() async {
        cachedDefaultResults.removeAll()
        cachedIndustryResults.removeAll()
        cachedTasteResults.removeAll()
        cachedPlaceResults.removeAll()
        cachedLocationResults.removeAll()
        cachedRecommendationData.removeAll()
        allCachedTastes.removeAll()
        allCachedResults.removeAll()
    }

    // MARK: - Helper Methods to Create Results

    private func createCategoryResults(from records: [UserCachedRecord]) -> [CategoryResult] {
        var results = [CategoryResult]()
        for (index, record) in records.enumerated() {
            let chatResults = [ChatResult(
                index: index,
                identity: record.identity,
                title: record.title,
                list: record.list,
                icon: record.icons,
                rating: record.rating,
                section: PersonalizedSearchSection(rawValue: record.section) ?? .topPicks,
                placeResponse: nil,
                recommendedPlaceResponse: nil
            )]
            let categoryResult = CategoryResult(
                identity: record.identity,
                parentCategory: record.title,
                list: record.list,
                icon: record.icons,
                rating: record.rating,
                section: PersonalizedSearchSection(rawValue: record.section) ?? .topPicks,
                categoricalChatResults: chatResults
            )
            results.append(categoryResult)
        }
        return results.sorted(by: { $0.parentCategory.lowercased() < $1.parentCategory.lowercased() })
    }

    private func createPlaceResults(from records: [UserCachedRecord]) -> [CategoryResult] {
        var results = [CategoryResult]()
        for (index, record) in records.enumerated() {
            let resolvedName = record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Place \(record.identity.prefix(8))"
                : record.title

            let placeResponse = PlaceSearchResponse(
                fsqID: record.identity,
                name: resolvedName,
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

            let chatResults = [ChatResult(
                index: index,
                identity: record.identity, title: record.title,
                list: record.list,
                icon: record.icons,
                rating: record.rating,
                section: PersonalizedSearchSection(rawValue: record.section) ?? .topPicks,
                placeResponse: placeResponse,
                recommendedPlaceResponse: nil
            )]
            let categoryResult = CategoryResult(
                identity: record.identity,
                parentCategory: record.title,
                list: record.list,
                icon: record.icons,
                rating: record.rating,
                section: PersonalizedSearchSection(rawValue: record.section) ?? .topPicks,
                categoricalChatResults: chatResults
            )
            results.append(categoryResult)
        }
        return results.sorted(by: { $0.parentCategory.lowercased() < $1.parentCategory.lowercased() })
    }

    private func createLocationResults(from records: [UserCachedRecord]) -> [LocationResult] {
        var results = [LocationResult]()
        for record in records {
            let components = record.identity.split(separator: ",")
            if components.count == 2,
               let latitude = Double(components[0]),
               let longitude = Double(components[1]) {
                let location = CLLocation(latitude: latitude, longitude: longitude)
                let locationResult = LocationResult(locationName: record.title, location: location)
                results.append(locationResult)
            }
        }
        return results
    }

    private func defaultResults() -> [CategoryResult] {
        PersonalizedSearchSection.allCases
            .map({ $0.categoryResult() })
    }

    @MainActor
    public func getAllCachedCategoryResults() -> [CategoryResult] {
        var results = cachedIndustryResults + cachedTasteResults +  cachedDefaultResults + cachedPlaceResults
        results.sort { $0.parentCategory.lowercased() < $1.parentCategory.lowercased() }
        return results
    }

    // MARK: - Cached Records Methods
    @MainActor
    public func cachedCategories(contains category: String) -> Bool {
        return cachedIndustryResults.contains { $0.parentCategory == category }
    }
    @MainActor
    public func cachedTastes(contains taste: String) -> Bool {
        return cachedTasteResults.contains { $0.parentCategory == taste }
    }
    @MainActor
    public func cachedLocation(contains location: String) -> Bool {
        return cachedLocationResults.contains { $0.locationName == location }
    }
    @MainActor
    public func cachedPlaces(contains place: String) -> Bool {
        return cachedPlaceResults.contains { $0.parentCategory == place }
    }
    @MainActor
    public func proactivelyCacheFavorites() async {
        guard let pcf = proactiveCacheService, let pss = placeSearchService else { return }
        
        // Combine all favorite search terms
        let favoriteTerms = (cachedIndustryResults + cachedTasteResults).map { $0.parentCategory }
        let favoritePlaces = cachedPlaceResults.map { $0.identity }
        
        // We use a limited set to avoid hitting API too hard at once, prioritizing tastes
        let termsToCache = Array(favoriteTerms.prefix(10))
        let placesToCache = Array(favoritePlaces.prefix(10))
        
        await withTaskGroup(of: Void.self) { group in
            // Cache search results for terms
            for term in termsToCache {
                group.addTask {
                    do {
                        // This will trigger PlaceSearchSession's fetch which now auto-caches to ProactiveCacheService
                        _ = try await pss.fetchPlaceSearchResponse(for: term, location: nil)
                    } catch {
                        self.analyticsManager.trackError(error: error, additionalInfo: ["context": "proactiveCache.term", "term": term])
                    }
                }
            }
            
            // Cache details for places
            for fsqID in placesToCache {
                group.addTask {
                    do {
                        _ = try await pss.fetchPlaceDetailsResponse(for: fsqID)
                    } catch {
                        self.analyticsManager.trackError(error: error, additionalInfo: ["context": "proactiveCache.place", "fsqID": fsqID])
                    }
                }
            }
        }
    }
    @MainActor
    public func cachedLocationIdentity(for location: CLLocation) -> String {
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
}



