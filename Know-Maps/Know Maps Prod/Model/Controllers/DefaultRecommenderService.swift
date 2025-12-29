//
//  RecommenderService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/9/24.
//
import Foundation
#if canImport(CreateML)
import CreateML
#endif
import TabularData
import CoreML

struct RecommenderTableData: Hashable, Codable {
    public let identity: String
    public let attribute: String
    public let rating: Double
}

public final class DefaultRecommenderService: RecommenderService {
    
    // MARK: - Shared helper for any category-like input
    
    // Accept arrays of a single concrete conforming type
    private func recommendationData<C: RecommendationCategoryConvertible>(
        from categoryResults: [C]
    ) -> [RecommendationData] {
        categoryResults.map { result in
            RecommendationData(
                id: UUID(),
                recordId: "",
                identity: result.recommenderIdentity,
                attributes: [result.recommenderAttribute],
                reviews: [],
                attributeRatings: [
                    result.recommenderAttribute: result.recommenderRating
                ]
            )
        }
    }
    
    private func recommendationData(
        from categoryResults: [any RecommendationCategoryConvertible]
    ) -> [RecommendationData] {
        categoryResults.map { result in
            RecommendationData(
                id: UUID(),
                recordId: "",
                identity: result.recommenderIdentity,
                attributes: [result.recommenderAttribute],
                reviews: [],
                attributeRatings: [
                    result.recommenderAttribute: result.recommenderRating
                ]
            )
        }
    }
    
    // MARK: - Existing public API (still works the same)
    
    public func recommendationData(
        tasteCategoryResults: [CategoryResult],
        industryCategoryResults: [CategoryResult],
        placeRecommendationData: [RecommendationData]
    ) -> [RecommendationData] {
        var retval = [RecommendationData]()
        
        // Use the shared helper instead of duplicating logic.
        retval.append(contentsOf: recommendationData(from: tasteCategoryResults))
        retval.append(contentsOf: recommendationData(from: industryCategoryResults))
        retval.append(contentsOf: placeRecommendationData)
        
        return retval
    }
    
    /// Optional: a more generic API you can start using for new category types
    public func recommendationData(
        categoryGroups: [[any RecommendationCategoryConvertible]],
        placeRecommendationData: [RecommendationData]
    ) -> [RecommendationData] {
        var retval = [RecommendationData]()
        
        for group in categoryGroups {
            retval.append(contentsOf: recommendationData(from: group))
        }
        
        retval.append(contentsOf: placeRecommendationData)
        return retval
    }
    
    public func testingData(
        with responses: [PlaceSearchResponse]
    ) -> [RecommendationData] {
        var retval = [RecommendationData]()
        
        for response in responses {
            if let tastes = response.tastes {
                for taste in tastes {
                    let data = RecommendationData(
                        id: UUID(),
                        recordId: "",
                        identity: response.fsqID,
                        attributes: [taste],
                        reviews: [],
                        attributeRatings: [taste: 1]
                    )
                    retval.append(data)
                }
            }
            
            for category in response.categories {
                let data = RecommendationData(
                    id: UUID(),
                    recordId: "",
                    identity: response.fsqID,
                    attributes: [category],
                    reviews: [],
                    attributeRatings: [category: 1]
                )
                retval.append(data)
            }
        }
        
        return retval
    }
    
    #if canImport(CreateML)
    public func model(with recommendationData: [RecommendationData]) throws -> MLRandomForestRegressor {
        
        var identities = [String]()
        var attributes = [String]()
        var ratings = [Double]()
        
        for recomendationDatum in recommendationData {
            for attributeRating in recomendationDatum.attributeRatings {
                identities.append(recomendationDatum.identity)
                attributes.append(attributeRating.key)
                ratings.append(attributeRating.value)
            }
        }
        
        let trainingData: DataFrame = [
            "identity": identities,
            "attribute": attributes,
            "rating": ratings
        ]
        
        let params = MLRandomForestRegressor.ModelParameters(
            validation: .split(strategy: .automatic),
            maxIterations: 100
        )
        
        let model = try MLRandomForestRegressor(
            trainingData: trainingData,
            targetColumn: "rating",
            parameters: params
        )
        
        return model
    }
    
    public func recommend(
        from testingData: [RecommendationData],
        with model: MLRandomForestRegressor
    ) throws -> [RecommendationData] {
        var retval = testingData
        
        var identities = [String]()
        var attributes = [String]()
        
        for testingDatum in testingData {
            for attribute in testingDatum.attributes {
                identities.append(testingDatum.identity)
                attributes.append(attribute)
            }
        }
        
        let test: DataFrame = [
            "identity": identities,
            "attribute": attributes
        ]
        
        let results = try model.predictions(from: test)
        
        for index in 0..<results.count {
            var retvalDatum = retval[index]
            retvalDatum.attributeRatings.removeAll()
            if let result = results[index] as? Double {
                retvalDatum.attributeRatings = [attributes[index]: result]
            }
            retval[index] = retvalDatum
        }
        
        return retval
    }
    #endif
}
