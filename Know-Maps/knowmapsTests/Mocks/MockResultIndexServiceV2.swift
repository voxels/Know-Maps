//
//  MockResultIndexServiceV2.swift
//  knowmapsTests
//

import Foundation
@testable import Know_Maps

@MainActor
public final class MockResultIndexServiceV2: ResultIndexServiceV2 {
    public var mockResults: [ChatResult] = []
    public var lastSearchQuery: String?
    
    public init() {}
    
    public func chatResult(index: Int, for service: any PlaceSearchService) -> ChatResult? {
        guard index >= 0 && index < mockResults.count else { return nil }
        return mockResults[index]
    }
    
    public func clearIndex() {}
    public func index(chatResults: [ChatResult]) {}
    public func search(query: String) -> [ChatResult] {
        lastSearchQuery = query
        return mockResults.filter { $0.title.contains(query) }
    }
    
    public func updateIndex(placeResults: [ChatResult], recommendedPlaceResults: [ChatResult], relatedPlaceResults: [ChatResult], industryResults: [CategoryResult], tasteResults: [CategoryResult], cachedIndustryResults: [CategoryResult], cachedPlaceResults: [CategoryResult], cachedTasteResults: [CategoryResult], cachedDefaultResults: [CategoryResult], cachedRecommendationData: [RecommendationData]) {}
    
    public func findResult(for id: CategoryResult.ID) -> ChatResult? { return nil }
    public func filteredPlaceResults() -> [ChatResult] { return [] }
    public func placeChatResult(for id: ChatResult.ID) -> ChatResult? { return nil }
    public func placeChatResult(with fsqID: String) -> ChatResult? { return nil }
    public func chatResult(title: String) -> ChatResult? { return nil }
    public func industryChatResult(for id: ChatResult.ID) -> ChatResult? { return nil }
    public func tasteChatResult(for id: CategoryResult.ID) -> ChatResult? { return nil }
    public func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult? { return nil }
    public func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult? { return nil }
    public func cachedIndustryResult(for id: CategoryResult.ID) -> CategoryResult? { return nil }
    public func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult? { return nil }
    public func cachedChatResult(for id: CategoryResult.ID) -> ChatResult? { return nil }
    public func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? { return nil }
    public func cachedTasteResultTitle(_ title: String) -> CategoryResult? { return nil }
    public func cachedRecommendationData(for identity: String) -> RecommendationData? { return nil }
    public func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult? { return nil }
    public func locationChatResult(with title: String, in locationResults: [LocationResult], locationService: (any LocationService)?, analyticsManager: any AnalyticsService) async -> LocationResult? { return nil }
}
