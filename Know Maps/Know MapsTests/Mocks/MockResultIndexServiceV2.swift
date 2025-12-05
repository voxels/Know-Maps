//
//  MockResultIndexServiceV2.swift
//  Know MapsTests
//
//  Mock implementation of ResultIndexServiceV2 for testing
//

import Foundation
@testable import Know_Maps_Prod

@MainActor
public final class MockResultIndexServiceV2: ResultIndexServiceV2 {

    // MARK: - Call Tracking

    public var updateIndexCalled = false
    public var filteredPlaceResultsCalled = false
    public var placeChatResultForIDCalled = false
    public var placeChatResultWithFsqIDCalled = false
    public var chatResultTitleCalled = false
    public var industryChatResultCalled = false
    public var tasteChatResultCalled = false
    public var industryCategoryResultCalled = false
    public var tasteCategoryResultCalled = false
    public var cachedIndustryResultCalled = false
    public var cachedPlaceResultCalled = false
    public var cachedChatResultCalled = false
    public var cachedTasteResultCalled = false
    public var cachedTasteResultTitleCalled = false
    public var cachedRecommendationDataCalled = false
    public var locationChatResultForIDCalled = false
    public var locationChatResultWithTitleCalled = false

    // MARK: - Call Counters

    public var updateIndexCallCount = 0
    public var filteredPlaceResultsCallCount = 0
    public var placeChatResultForIDCallCount = 0
    public var placeChatResultWithFsqIDCallCount = 0
    public var chatResultTitleCallCount = 0
    public var industryChatResultCallCount = 0
    public var tasteChatResultCallCount = 0
    public var industryCategoryResultCallCount = 0
    public var tasteCategoryResultCallCount = 0
    public var cachedIndustryResultCallCount = 0
    public var cachedPlaceResultCallCount = 0
    public var cachedChatResultCallCount = 0
    public var cachedTasteResultCallCount = 0
    public var cachedTasteResultTitleCallCount = 0
    public var cachedRecommendationDataCallCount = 0
    public var locationChatResultForIDCallCount = 0
    public var locationChatResultWithTitleCallCount = 0

    // MARK: - Last Call Arguments

    public var lastUpdateIndexArgs: (
        placeResults: [ChatResult],
        recommendedPlaceResults: [ChatResult],
        relatedPlaceResults: [ChatResult],
        industryResults: [CategoryResult],
        tasteResults: [CategoryResult],
        cachedIndustryResults: [CategoryResult],
        cachedPlaceResults: [CategoryResult],
        cachedTasteResults: [CategoryResult],
        cachedRecommendationData: [RecommendationData]
    )?
    public var lastPlaceChatResultID: String?
    public var lastPlaceChatResultFsqID: String?
    public var lastChatResultTitle: String?
    public var lastIndustryChatResultID: String?
    public var lastTasteChatResultID: String?
    public var lastIndustryCategoryResultID: String?
    public var lastTasteCategoryResultID: String?
    public var lastCachedIndustryResultID: String?
    public var lastCachedPlaceResultID: String?
    public var lastCachedChatResultID: String?
    public var lastCachedTasteResultID: String?
    public var lastCachedTasteResultTitle: String?
    public var lastCachedRecommendationDataIdentity: String?
    public var lastLocationChatResultID: String?
    public var lastLocationChatResultTitle: String?

    // MARK: - Configurable Mock Responses

    public var mockFilteredPlaceResults: [ChatResult] = []
    public var mockPlaceChatResultForID: ChatResult?
    public var mockPlaceChatResultWithFsqID: ChatResult?
    public var mockChatResultTitle: ChatResult?
    public var mockIndustryChatResult: ChatResult?
    public var mockTasteChatResult: ChatResult?
    public var mockIndustryCategoryResult: CategoryResult?
    public var mockTasteCategoryResult: CategoryResult?
    public var mockCachedIndustryResult: CategoryResult?
    public var mockCachedPlaceResult: CategoryResult?
    public var mockCachedChatResult: ChatResult?
    public var mockCachedTasteResult: CategoryResult?
    public var mockCachedTasteResultTitle: CategoryResult?
    public var mockCachedRecommendationData: RecommendationData?
    public var mockLocationChatResultForID: LocationResult?
    public var mockLocationChatResultWithTitle: LocationResult?

    // MARK: - Protocol Implementation

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
        updateIndexCalled = true
        updateIndexCallCount += 1
        lastUpdateIndexArgs = (
            placeResults,
            recommendedPlaceResults,
            relatedPlaceResults,
            industryResults,
            tasteResults,
            cachedIndustryResults,
            cachedPlaceResults,
            cachedTasteResults,
            cachedRecommendationData
        )
    }

    public func filteredPlaceResults() -> [ChatResult] {
        filteredPlaceResultsCalled = true
        filteredPlaceResultsCallCount += 1
        return mockFilteredPlaceResults
    }

    public func placeChatResult(for id: ChatResult.ID) -> ChatResult? {
        placeChatResultForIDCalled = true
        placeChatResultForIDCallCount += 1
        lastPlaceChatResultID = id
        return mockPlaceChatResultForID
    }

    public func placeChatResult(with fsqID: String) -> ChatResult? {
        placeChatResultWithFsqIDCalled = true
        placeChatResultWithFsqIDCallCount += 1
        lastPlaceChatResultFsqID = fsqID
        return mockPlaceChatResultWithFsqID
    }

    public func chatResult(title: String) -> ChatResult? {
        chatResultTitleCalled = true
        chatResultTitleCallCount += 1
        lastChatResultTitle = title
        return mockChatResultTitle
    }

    public func industryChatResult(for id: ChatResult.ID) -> ChatResult? {
        industryChatResultCalled = true
        industryChatResultCallCount += 1
        lastIndustryChatResultID = id
        return mockIndustryChatResult
    }

    public func tasteChatResult(for id: CategoryResult.ID) -> ChatResult? {
        tasteChatResultCalled = true
        tasteChatResultCallCount += 1
        lastTasteChatResultID = id
        return mockTasteChatResult
    }

    public func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        industryCategoryResultCalled = true
        industryCategoryResultCallCount += 1
        lastIndustryCategoryResultID = id
        return mockIndustryCategoryResult
    }

    public func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        tasteCategoryResultCalled = true
        tasteCategoryResultCallCount += 1
        lastTasteCategoryResultID = id
        return mockTasteCategoryResult
    }

    public func cachedIndustryResult(for id: CategoryResult.ID) -> CategoryResult? {
        cachedIndustryResultCalled = true
        cachedIndustryResultCallCount += 1
        lastCachedIndustryResultID = id
        return mockCachedIndustryResult
    }

    public func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult? {
        cachedPlaceResultCalled = true
        cachedPlaceResultCallCount += 1
        lastCachedPlaceResultID = id
        return mockCachedPlaceResult
    }

    public func cachedChatResult(for id: CategoryResult.ID) -> ChatResult? {
        cachedChatResultCalled = true
        cachedChatResultCallCount += 1
        lastCachedChatResultID = id
        return mockCachedChatResult
    }

    public func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? {
        cachedTasteResultCalled = true
        cachedTasteResultCallCount += 1
        lastCachedTasteResultID = id
        return mockCachedTasteResult
    }

    public func cachedTasteResultTitle(_ title: String) -> CategoryResult? {
        cachedTasteResultTitleCalled = true
        cachedTasteResultTitleCallCount += 1
        lastCachedTasteResultTitle = title
        return mockCachedTasteResultTitle
    }

    public func cachedRecommendationData(for identity: String) -> RecommendationData? {
        cachedRecommendationDataCalled = true
        cachedRecommendationDataCallCount += 1
        lastCachedRecommendationDataIdentity = identity
        return mockCachedRecommendationData
    }

    public func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult? {
        locationChatResultForIDCalled = true
        locationChatResultForIDCallCount += 1
        lastLocationChatResultID = id
        return mockLocationChatResultForID
    }

    public func locationChatResult(
        with title: String,
        in locationResults: [LocationResult],
        locationService: LocationService,
        analyticsManager: AnalyticsService
    ) async -> LocationResult? {
        locationChatResultWithTitleCalled = true
        locationChatResultWithTitleCallCount += 1
        lastLocationChatResultTitle = title
        return mockLocationChatResultWithTitle
    }

    // MARK: - Test Helpers

    public func reset() {
        // Reset call tracking
        updateIndexCalled = false
        filteredPlaceResultsCalled = false
        placeChatResultForIDCalled = false
        placeChatResultWithFsqIDCalled = false
        chatResultTitleCalled = false
        industryChatResultCalled = false
        tasteChatResultCalled = false
        industryCategoryResultCalled = false
        tasteCategoryResultCalled = false
        cachedIndustryResultCalled = false
        cachedPlaceResultCalled = false
        cachedChatResultCalled = false
        cachedTasteResultCalled = false
        cachedTasteResultTitleCalled = false
        cachedRecommendationDataCalled = false
        locationChatResultForIDCalled = false
        locationChatResultWithTitleCalled = false

        // Reset counters
        updateIndexCallCount = 0
        filteredPlaceResultsCallCount = 0
        placeChatResultForIDCallCount = 0
        placeChatResultWithFsqIDCallCount = 0
        chatResultTitleCallCount = 0
        industryChatResultCallCount = 0
        tasteChatResultCallCount = 0
        industryCategoryResultCallCount = 0
        tasteCategoryResultCallCount = 0
        cachedIndustryResultCallCount = 0
        cachedPlaceResultCallCount = 0
        cachedChatResultCallCount = 0
        cachedTasteResultCallCount = 0
        cachedTasteResultTitleCallCount = 0
        cachedRecommendationDataCallCount = 0
        locationChatResultForIDCallCount = 0
        locationChatResultWithTitleCallCount = 0

        // Reset arguments
        lastUpdateIndexArgs = nil
        lastPlaceChatResultID = nil
        lastPlaceChatResultFsqID = nil
        lastChatResultTitle = nil
        lastIndustryChatResultID = nil
        lastTasteChatResultID = nil
        lastIndustryCategoryResultID = nil
        lastTasteCategoryResultID = nil
        lastCachedIndustryResultID = nil
        lastCachedPlaceResultID = nil
        lastCachedChatResultID = nil
        lastCachedTasteResultID = nil
        lastCachedTasteResultTitle = nil
        lastCachedRecommendationDataIdentity = nil
        lastLocationChatResultID = nil
        lastLocationChatResultTitle = nil

        // Reset mock responses
        mockFilteredPlaceResults = []
        mockPlaceChatResultForID = nil
        mockPlaceChatResultWithFsqID = nil
        mockChatResultTitle = nil
        mockIndustryChatResult = nil
        mockTasteChatResult = nil
        mockIndustryCategoryResult = nil
        mockTasteCategoryResult = nil
        mockCachedIndustryResult = nil
        mockCachedPlaceResult = nil
        mockCachedChatResult = nil
        mockCachedTasteResult = nil
        mockCachedTasteResultTitle = nil
        mockCachedRecommendationData = nil
        mockLocationChatResultForID = nil
        mockLocationChatResultWithTitle = nil
    }
}
