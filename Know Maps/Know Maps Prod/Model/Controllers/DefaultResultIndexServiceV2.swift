//
//  DefaultResultIndexServiceV2.swift
//  Know Maps
//
//  Default implementation of ResultIndexServiceV2 with O(1) dictionary-based lookups
//

import Foundation

@MainActor
@Observable
public final class DefaultResultIndexServiceV2: ResultIndexServiceV2 {

    // MARK: - Stored Data

    private var placeResults: [ChatResult] = []
    private var recommendedPlaceResults: [ChatResult] = []
    private var relatedPlaceResults: [ChatResult] = []
    private var industryResults: [CategoryResult] = []
    private var tasteResults: [CategoryResult] = []
    private var cachedIndustryResults: [CategoryResult] = []
    private var cachedPlaceResults: [CategoryResult] = []
    private var cachedTasteResults: [CategoryResult] = []
    private var cachedRecommendationData: [RecommendationData] = []

    // MARK: - O(1) Lookup Indices

    private var placeResultsByID: [String: ChatResult] = [:]
    private var recommendedPlaceResultsByID: [String: ChatResult] = [:]
    private var relatedPlaceResultsByID: [String: ChatResult] = [:]
    private var placeResultsByFsqID: [String: ChatResult] = [:]
    private var industryChatResultsByID: [String: ChatResult] = [:]
    private var industryCategoryResultsByID: [String: CategoryResult] = [:]
    private var tasteCategoryResultsByID: [String: CategoryResult] = [:]
    private var cachedIndustryResultsByID: [String: CategoryResult] = [:]
    private var cachedPlaceResultsByID: [String: CategoryResult] = [:]
    private var cachedChatResultsByID: [String: ChatResult] = [:]
    private var cachedTasteResultsByID: [String: CategoryResult] = [:]
    private var cachedTasteResultsByTitle: [String: CategoryResult] = [:]
    private var cachedRecommendationDataByIdentity: [String: RecommendationData] = [:]

    public init() {}

    // MARK: - Index Management

    public func updateIndex(
        placeResults: [ChatResult],
        recommendedPlaceResults: [ChatResult],
        relatedPlaceResults: [ChatResult],
        industryResults: [CategoryResult],
        tasteResults: [CategoryResult],
        cachedIndustryResults: [CategoryResult],
        cachedPlaceResults: [CategoryResult],
        cachedTasteResults: [CategoryResult],
        cachedRecommendationData: [RecommendationData]
    ) {
        // Store arrays
        self.placeResults = placeResults
        self.recommendedPlaceResults = recommendedPlaceResults
        self.relatedPlaceResults = relatedPlaceResults
        self.industryResults = industryResults
        self.tasteResults = tasteResults
        self.cachedIndustryResults = cachedIndustryResults
        self.cachedPlaceResults = cachedPlaceResults
        self.cachedTasteResults = cachedTasteResults
        self.cachedRecommendationData = cachedRecommendationData

        // Build indices
        buildPlaceResultsIndex()
        buildIndustryResultsIndex()
        buildTasteResultsIndex()
        buildCachedResultsIndex()
    }

    // MARK: - Private Index Builders

    private func buildPlaceResultsIndex() {
        placeResultsByID = Dictionary(uniqueKeysWithValues: placeResults.map { ($0.id, $0) })
        recommendedPlaceResultsByID = Dictionary(uniqueKeysWithValues: recommendedPlaceResults.map { ($0.id, $0) })
        relatedPlaceResultsByID = Dictionary(uniqueKeysWithValues: relatedPlaceResults.map { ($0.id, $0) })

        // Build fsqID index
        placeResultsByFsqID = [:]
        for result in placeResults {
            if let fsqID = result.placeResponse?.fsqID {
                placeResultsByFsqID[fsqID] = result
            }
        }
        for result in recommendedPlaceResults {
            if let fsqID = result.recommendedPlaceResponse?.fsqID {
                placeResultsByFsqID[fsqID] = result
            } else if let fsqID = result.placeResponse?.fsqID {
                placeResultsByFsqID[fsqID] = result
            }
        }
    }

    private func buildIndustryResultsIndex() {
        // Build category index (includes children via flatMap)
        let allIndustryCategories = industryResults.flatMap { [$0] + $0.children }
        industryCategoryResultsByID = Dictionary(uniqueKeysWithValues: allIndustryCategories.map { ($0.id, $0) })

        // Build chat result index
        industryChatResultsByID = [:]
        for category in industryResults {
            for chatResult in category.categoricalChatResults {
                industryChatResultsByID[chatResult.id] = chatResult
                if let parentId = chatResult.parentId {
                    industryChatResultsByID[parentId] = chatResult
                }
            }
        }
    }

    private func buildTasteResultsIndex() {
        tasteCategoryResultsByID = Dictionary(uniqueKeysWithValues: tasteResults.map { ($0.id, $0) })
    }

    private func buildCachedResultsIndex() {
        cachedIndustryResultsByID = Dictionary(uniqueKeysWithValues: cachedIndustryResults.map { ($0.id, $0) })
        cachedPlaceResultsByID = Dictionary(uniqueKeysWithValues: cachedPlaceResults.map { ($0.id, $0) })
        cachedTasteResultsByID = Dictionary(uniqueKeysWithValues: cachedTasteResults.map { ($0.id, $0) })
        cachedTasteResultsByTitle = Dictionary(uniqueKeysWithValues: cachedTasteResults.map { ($0.parentCategory, $0) })
        cachedRecommendationDataByIdentity = Dictionary(uniqueKeysWithValues: cachedRecommendationData.map { ($0.id.uuidString, $0) })

        print("🗂️ buildCachedResultsIndex: industry count = \(cachedIndustryResults.count), taste count = \(cachedTasteResults.count), place count = \(cachedPlaceResults.count)")

        // Build cached chat results index
        cachedChatResultsByID = [:]
        let allCachedCategories = cachedIndustryResults + cachedPlaceResults + cachedTasteResults
        print("🗂️ buildCachedResultsIndex: allCachedCategories count = \(allCachedCategories.count)")
        for category in allCachedCategories {
            // Try to use existing chat result first
            if let firstResult = category.categoricalChatResults.first {
                print("🗂️   Using existing chatResult for category.id = \(category.id) (\(category.parentCategory))")
                cachedChatResultsByID[category.id] = firstResult
            } else {
                // If categoricalChatResults is empty (e.g., loaded from cache), create a ChatResult from the category itself
                print("🗂️   Creating synthetic chatResult for category.id = \(category.id) (\(category.parentCategory))")
                let syntheticChatResult = ChatResult(
                    parentId: category.id,
                    index: 0,
                    identity: category.identity,
                    title: category.parentCategory,
                    list: category.list,
                    icon: category.icon,
                    rating: category.rating,
                    section: category.section,
                    placeResponse: nil,
                    recommendedPlaceResponse: nil,
                    placeDetailsResponse: nil
                )
                cachedChatResultsByID[category.id] = syntheticChatResult
            }
        }
        print("🗂️ buildCachedResultsIndex: cachedChatResultsByID final count = \(cachedChatResultsByID.count)")
        print("🗂️ buildCachedResultsIndex: cachedChatResultsByID keys = \(Array(cachedChatResultsByID.keys))")
    }

    // MARK: - Place Result Lookups

    public func filteredPlaceResults() -> [ChatResult] {
        return placeResults
    }

    public func placeChatResult(for id: ChatResult.ID) -> ChatResult? {
        // Search in order: recommended -> place -> related
        if let result = recommendedPlaceResultsByID[id] {
            return result
        }
        if let result = placeResultsByID[id] {
            return result
        }
        if let result = relatedPlaceResultsByID[id] {
            return result
        }
        return nil
    }

    public func placeChatResult(with fsqID: String) -> ChatResult? {
        return placeResultsByFsqID[fsqID]
    }

    // MARK: - Chat Result Lookups

    public func chatResult(title: String) -> ChatResult? {
        // Linear search through industry results for title match
        // This cannot be easily optimized without maintaining a title index
        return industryResults.compactMap { $0.result(title: title) }.first
    }

    public func industryChatResult(for id: ChatResult.ID) -> ChatResult? {
        return industryChatResultsByID[id]
    }

    public func tasteChatResult(for id: CategoryResult.ID) -> ChatResult? {
        return tasteCategoryResultsByID[id]?.categoricalChatResults.first
    }

    // MARK: - Category Result Lookups

    public func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return industryCategoryResultsByID[id]
    }

    public func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return tasteCategoryResultsByID[id]
    }

    // MARK: - Cached Result Lookups

    public func cachedIndustryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cachedIndustryResultsByID[id]
    }

    public func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cachedPlaceResultsByID[id]
    }

    public func cachedChatResult(for id: CategoryResult.ID) -> ChatResult? {
        return cachedChatResultsByID[id]
    }

    public func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cachedTasteResultsByID[id]
    }

    public func cachedTasteResultTitle(_ title: String) -> CategoryResult? {
        return cachedTasteResultsByTitle[title]
    }

    public func cachedRecommendationData(for identity: String) -> RecommendationData? {
        return cachedRecommendationDataByIdentity[identity]
    }

    // MARK: - Location Result Lookups

    public func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult? {
        // Location results are typically small arrays, so linear search is acceptable
        return locationResults.first { $0.id == id }
    }

    public func locationChatResult(
        with title: String,
        in locationResults: [LocationResult],
        locationService: LocationService,
        analyticsManager: AnalyticsService
    ) async -> LocationResult? {
        // First check existing results
        if let existingResult = locationResults.first(where: { $0.locationName == title }) {
            return existingResult
        }

        // Fallback to geocoding
        do {
            let placemarks = try await locationService.lookUpLocationName(name: title)
            if let firstPlacemark = placemarks.first, let location = firstPlacemark.location {
                let result = LocationResult(locationName: title, location: location)
                return result
            }
        } catch {
            Task { @MainActor in
                analyticsManager.trackError(error: error, additionalInfo: ["title": title])
            }
        }

        return nil
    }
}
