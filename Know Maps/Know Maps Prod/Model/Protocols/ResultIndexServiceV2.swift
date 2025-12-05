//
//  ResultIndexServiceV2.swift
//  Know Maps
//
//  Protocol for indexing and looking up search results
//  Provides O(1) dictionary-based lookups instead of O(n) array searches
//

import Foundation

@MainActor
public protocol ResultIndexServiceV2 {

    // MARK: - Index Management

    /// Updates internal indices for O(1) lookups after data changes
    func updateIndex(
        placeResults: [ChatResult],
        recommendedPlaceResults: [ChatResult],
        relatedPlaceResults: [ChatResult],
        industryResults: [CategoryResult],
        tasteResults: [CategoryResult],
        cachedIndustryResults: [CategoryResult],
        cachedPlaceResults: [CategoryResult],
        cachedTasteResults: [CategoryResult],
        cachedDefaultResults: [CategoryResult],
        cachedRecommendationData: [RecommendationData]
    )

    // MARK: - Place Result Lookups

    /// Returns filtered place results (non-empty results only)
    func filteredPlaceResults() -> [ChatResult]

    /// Finds a ChatResult by ID, searching recommended, place, and related results
    func placeChatResult(for id: ChatResult.ID) -> ChatResult?

    /// Finds a ChatResult by Foursquare ID
    func placeChatResult(with fsqID: String) -> ChatResult?

    // MARK: - Chat Result Lookups

    /// Finds a ChatResult in industry results by title
    func chatResult(title: String) -> ChatResult?

    /// Finds a ChatResult in industry results by ID
    func industryChatResult(for id: ChatResult.ID) -> ChatResult?

    /// Finds a ChatResult in taste results by category ID
    func tasteChatResult(for id: CategoryResult.ID) -> ChatResult?

    // MARK: - Category Result Lookups

    /// Finds an industry CategoryResult by ID (includes children)
    func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult?

    /// Finds a taste CategoryResult by ID
    func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult?

    // MARK: - Cached Result Lookups

    /// Finds a cached industry CategoryResult by ID
    func cachedIndustryResult(for id: CategoryResult.ID) -> CategoryResult?

    /// Finds a cached place CategoryResult by ID
    func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult?

    /// Finds a cached ChatResult by category ID
    func cachedChatResult(for id: CategoryResult.ID) -> ChatResult?

    /// Finds a cached taste CategoryResult by ID
    func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult?

    /// Finds a cached taste CategoryResult by title
    func cachedTasteResultTitle(_ title: String) -> CategoryResult?

    /// Finds cached RecommendationData by identity
    func cachedRecommendationData(for identity: String) -> RecommendationData?

    // MARK: - Location Result Lookups

    /// Finds a LocationResult by ID in the provided array
    func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult?

    /// Finds a LocationResult by title, with optional geocoding fallback
    func locationChatResult(
        with title: String,
        in locationResults: [LocationResult],
        locationService: LocationService,
        analyticsManager: AnalyticsService
    ) async -> LocationResult?
}
