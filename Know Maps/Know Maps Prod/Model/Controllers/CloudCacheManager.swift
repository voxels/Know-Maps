//
//  CloudCacheManager.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

@Observable
public final class CloudCacheManager: CacheManager {
    
    @MainActor
    static let shared = CloudCacheManager(cloudCache: CloudCacheService.shared, analyticsManager: SegmentAnalyticsService.shared)
    
    public let cloudCache: CloudCache
    private let analyticsManager: AnalyticsService
    public var isRefreshingCache: Bool = false
    public var cacheFetchProgress: Double = 0
    public var completedTasks = 0

    // Cached Results
     public var cachedDefaultResults = [CategoryResult]()
     public var cachedIndustryResults = [CategoryResult]()
     public var cachedTasteResults = [CategoryResult]()
     public var cachedPlaceResults = [CategoryResult]()
     public var allCachedResults = [CategoryResult]()
     public var cachedLocationResults = [LocationResult]()
     public var cachedRecommendationData = [RecommendationData]()

    public init(cloudCache: CloudCache, analyticsManager: AnalyticsService) {
        self.cloudCache = cloudCache
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

        await refreshCachedRecommendationData()
        await updateProgress(for: 6, totalTasks: totalTasks)

        // Update allCachedResults
        await refreshCachedResults()

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
    
    public func refreshCachedCategories() async {
        do {
            let records = try await cloudCache.fetchGroupedUserCachedRecords(for: "Category")
            let results = self.createCategoryResults(from: records)
            await MainActor.run {
                self.cachedIndustryResults = results
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    public func refreshCachedTastes() async {
        do {
            let records = try await cloudCache.fetchGroupedUserCachedRecords(for: "Taste")
            let results = self.createCategoryResults(from: records)
            await MainActor.run {
                self.cachedTasteResults = results
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    public func refreshCachedPlaces() async {
        do {
            let records = try await cloudCache.fetchGroupedUserCachedRecords(for: "Place")
            let results = self.createPlaceResults(from: records)
            await MainActor.run {
                self.cachedPlaceResults = results
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    public func refreshCachedLocations() async {
        do {
            let records = try await cloudCache.fetchGroupedUserCachedRecords(for: "Location")
            let locationResults = self.createLocationResults(from: records)
            await MainActor.run {
                self.cachedLocationResults = locationResults
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    public func refreshCachedRecommendationData() async {
        do {
            let records = try await cloudCache.fetchRecommendationData()
            await MainActor.run {
                self.cachedRecommendationData = records
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

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
        print("Restoring all cache records")
        try await cloudCache.fetchAllRecords(recordTypes: ["UserCachedRecord", "RecommendationData"])
    }

    @MainActor
    public func clearCache() {
        cachedDefaultResults.removeAll()
        cachedIndustryResults.removeAll()
        cachedTasteResults.removeAll()
        cachedPlaceResults.removeAll()
        cachedLocationResults.removeAll()
        cachedRecommendationData.removeAll()
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

    public func getAllCachedCategoryResults() -> [CategoryResult] {
        var results = cachedIndustryResults + cachedTasteResults +  cachedDefaultResults + cachedPlaceResults
        results.sort { $0.parentCategory.lowercased() < $1.parentCategory.lowercased() }
        return results
    }

    // MARK: - Cached Records Methods

    public func cachedCategories(contains category: String) -> Bool {
        return cachedIndustryResults.contains { $0.parentCategory == category }
    }

    public func cachedTastes(contains taste: String) -> Bool {
        return cachedTasteResults.contains { $0.parentCategory == taste }
    }

    public func cachedLocation(contains location: String) -> Bool {
        return cachedLocationResults.contains { $0.locationName == location }
    }

    public func cachedPlaces(contains place: String) -> Bool {
        return cachedPlaceResults.contains { $0.parentCategory == place }
    }

    public func cachedLocationIdentity(for location: CLLocation) -> String {
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
}

