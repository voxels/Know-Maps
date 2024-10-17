//
//  Recommender.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/9/24.
//

import Foundation
#if canImport(CreateML)
import CreateML
#endif

public protocol RecommenderService : Sendable {
    func recommendationData(tasteCategoryResults: [CategoryResult], industryCategoryResults: [CategoryResult], placeRecommendationData:[RecommendationData]) -> [RecommendationData]
    func testingData(with responses:[RecommendedPlaceSearchResponse])->[RecommendationData]

#if canImport(CreateML)
    func model(with recommendationData: [RecommendationData]) throws -> MLRandomForestRegressor
    func recommend(from testingData: [RecommendationData], with model: MLRandomForestRegressor) throws -> [RecommendationData]
#endif
}
