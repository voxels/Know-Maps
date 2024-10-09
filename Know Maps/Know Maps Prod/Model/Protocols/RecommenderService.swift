//
//  Recommender.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/9/24.
//

import Foundation
import CreateML

public protocol RecommenderService {
    func recommendationData(tasteCategoryResults: [CategoryResult], industryCategoryResults: [CategoryResult], placeRecommendationData:[RecommendationData]) -> [RecommendationData]
    func model(with recommendationData: [RecommendationData]) throws -> MLLinearRegressor
    func testingData(with responses:[RecommendedPlaceSearchResponse])->[RecommendationData]
    func recommend(from testingData: [RecommendationData], with model: MLLinearRegressor) throws -> [RecommendationData]}
