//
//  RecommenderService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/9/24.
//

import Foundation
import CreateML
import TabularData
import CoreML

struct RecommenderTableData : Hashable, Codable {
    public let identity:String
    public let attribute:String
    public let rating:Double
}

public final class DefaultRecommenderService : RecommenderService {
    public func recommendationData(tasteCategoryResults: [CategoryResult], industryCategoryResults: [CategoryResult], placeRecommendationData:[RecommendationData]) -> [RecommendationData] {
        var retval = [RecommendationData]()
        
        for tasteCategoryResult in tasteCategoryResults {
            let data = RecommendationData(recordId: "", identity: tasteCategoryResult.parentCategory, attributes: [tasteCategoryResult.parentCategory], reviews: [], attributeRatings: [tasteCategoryResult.parentCategory: tasteCategoryResult.rating])
            retval.append(data)
        }
        
        for industryCategoryResult in industryCategoryResults {
            let data = RecommendationData(recordId: "", identity: industryCategoryResult.parentCategory, attributes: [industryCategoryResult.parentCategory], reviews: [], attributeRatings: [industryCategoryResult.parentCategory: industryCategoryResult.rating])
            retval.append(data)
        }
    
        retval.append(contentsOf: placeRecommendationData)
        
        return retval
    }
    
    public func testingData(with responses:[RecommendedPlaceSearchResponse])->[RecommendationData] {
        var retval = [RecommendationData]()
        
        for response in responses {
            for taste in response.tastes {
                let data = RecommendationData(recordId: "", identity:response.fsqID, attributes: [taste], reviews: [], attributeRatings: [taste: 1])
                retval.append(data)
            }
            
            for category in response.categories {
                let data = RecommendationData(recordId: "", identity:response.fsqID, attributes: [category], reviews: [], attributeRatings: [category: 1])
                retval.append(data)
            }
        }
        
        return retval
    }
    
    public func model(with recommendationData: [RecommendationData]) throws -> MLLinearRegressor {
        
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
        
        let trainingData:DataFrame = ["identity": identities,"attribute":attributes,"rating":ratings]
        let model = try MLLinearRegressor(trainingData: trainingData, targetColumn: "rating")
        
        
        return model
    }
    
    public func recommend(from testingData: [RecommendationData], with model: MLLinearRegressor) throws -> [RecommendationData] {
        var retval = testingData
        
        var identities = [String]()
        var attributes = [String]()
        
        for testingDatum in testingData {
            for attribute in testingDatum.attributes {
                identities.append(testingDatum.identity)
                attributes.append(attribute)
            }
        }
        
        let test:DataFrame = ["identity":identities,"attribute":attributes]
        
        let results = try model.predictions(from: test)
        
        for index in 0..<results.count {
            var retvalDatum = retval[index]
            retvalDatum.attributeRatings.removeAll()
            if let result = results[index] as? Double {
                retvalDatum.attributeRatings = [attributes[index]:result]
            }
            retval[index] = retvalDatum
        }
        
        return retval
    }
}
