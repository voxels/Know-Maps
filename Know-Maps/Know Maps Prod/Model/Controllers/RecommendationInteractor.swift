//
//  RecommendationInteractor.swift
//  Know Maps
//
//  Created for SOLID Refactor.
//

import Foundation
import ConcurrencyExtras

@MainActor
final class RecommendationInteractor {
    private let recommenderService: RecommenderService
    private let cacheManager: CacheManager
    private let analyticsManager: AnalyticsService
    
    // In-flight tracking
    private var inFlightComponentKeys: Set<String> = []
    
    init(
        recommenderService: RecommenderService,
        cacheManager: CacheManager,
        analyticsManager: AnalyticsService
    ) {
        self.recommenderService = recommenderService
        self.cacheManager = cacheManager
        self.analyticsManager = analyticsManager
    }
    
    // MARK: - Recommended Place Query
    
    // MARK: - Recommended Place Query
    
    struct RecommendationResult {
        let results: [ChatResult]
        let modelMessage: String?
    }
    
    func fetchRecommendations(
        intent: AssistiveChatHostIntent,
        locationName: String
    ) async throws -> [ChatResult] {
        let recResponses = intent.fulfillment.recommendations ?? []
        // Early exit: nothing to do
        guard !recResponses.isEmpty else { return [] }
        
        let caption = intent.caption
        let section: PersonalizedSearchSection = .topPicks
        
        #if canImport(CreateML)
        let hasSufficientTrainingData = (
            cacheManager.cachedTasteResults.count > 2 ||
            cacheManager.cachedIndustryResults.count > 2
        )
        #else
        let hasSufficientTrainingData = false
        #endif
        
        // Heavy compute off-main
        let sortedResults: [ChatResult] = try await Task.detached(priority: .userInitiated) { [weak self, recommenderService] in
            guard let self else { return [] }
            
            let precomputedTrainingData: [RecommendationData] = hasSufficientTrainingData ? {
                let categoryGroups: [[any RecommendationCategoryConvertible]] = [
                    self.cacheManager.cachedTasteResults,
                    self.cacheManager.cachedIndustryResults
                ]
                return recommenderService.recommendationData(
                    categoryGroups: categoryGroups,
                    placeRecommendationData: self.cacheManager.cachedRecommendationData
                )
            }() : []

            var recommendedChatResults = [ChatResult]()
            
            #if canImport(CreateML)
            if recResponses.count > 1 {
                if hasSufficientTrainingData {
                    let model = try recommenderService.model(with: precomputedTrainingData)
                    let testingData = recommenderService.testingData(with: recResponses)
                    let recommenderResults = try recommenderService.recommend(from: testingData, with: model)
                    
                    for index in 0..<recResponses.count {
                        let response = recResponses[index]
                        guard !response.fsqID.isEmpty else { continue }
                        
                        let rating = index < recommenderResults.count
                            ? (recommenderResults[index].attributeRatings.first?.value ?? 1)
                            : 1
                        
                        let placeResponse = self.createPlaceSearchResponse(from: response)
                        
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeResponse,
                            section: section,
                            list: caption,
                            index: index,
                            rating: rating,
                            details: nil
                        )
                        recommendedChatResults.append(contentsOf: results)
                    }
                } else {
                    for index in 0..<recResponses.count {
                        let response = recResponses[index]
                        guard !response.fsqID.isEmpty else { continue }
                        let placeResponse = self.createPlaceSearchResponse(from: response)
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeResponse,
                            section: section,
                            list: caption,
                            index: index,
                            rating: 1,
                            details: nil
                        )
                        recommendedChatResults.append(contentsOf: results)
                    }
                }
            } else {
                if let response = recResponses.first, !response.fsqID.isEmpty {
                    let placeResponse = self.createPlaceSearchResponse(from: response)
                    let results = PlaceResponseFormatter.placeChatResults(
                        for: intent,
                        place: placeResponse,
                        section: section,
                        list: caption,
                        index: 0,
                        rating: 1,
                        details: nil
                    )
                    recommendedChatResults.append(contentsOf: results)
                }
            }
            #else
            for index in 0..<recResponses.count {
                let response = recResponses[index]
                guard !response.fsqID.isEmpty else { continue }
                let placeResponse = self.createPlaceSearchResponse(from: response)
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: placeResponse,
                    section: section,
                    list: caption,
                    index: index,
                    rating: 1,
                    details: nil
                )
                recommendedChatResults.append(contentsOf: results)
            }
            #endif
            
            // Sort deterministically off-main
            let sorted = recommendedChatResults.sorted { lhs, rhs in
                if lhs.rating == rhs.rating { return lhs.index < rhs.index }
                return lhs.rating > rhs.rating
            }
            return sorted
        }.value
        
        return sortedResults
    }
    
    nonisolated private func createPlaceSearchResponse(from response: PlaceSearchResponse) -> PlaceSearchResponse {
        return PlaceSearchResponse(
            fsqID: response.fsqID,
            name: response.name,
            categories: response.categories,
            latitude: response.latitude,
            longitude: response.longitude,
            address: response.address ?? "",
            addressExtended: response.formattedAddress ?? "",
            country: response.country ?? "",
            dma: response.neighborhood ?? "",
            formattedAddress: response.formattedAddress ?? "",
            locality: response.city ?? "",
            postCode: response.postCode ?? "",
            region: response.state ?? "",
            chains: [],
            link: "",
            childIDs: [],
            parentIDs: []
        )
    }

}
