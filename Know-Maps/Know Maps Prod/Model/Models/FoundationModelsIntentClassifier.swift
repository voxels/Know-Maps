//
//  FoundationModelsIntentClassifier.swift
//  Know Maps
//
//  Created on 11/26/24.
//

import Foundation
import NaturalLanguage

public actor FoundationModelsIntentClassifier {
    
    // MARK: - Properties
    
    // private let tagger: NLTagger // Commented out
    
    // MARK: - Initialization
    
    public init() {
       // self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    }
    
    // MARK: - Public Methods
    
    public func classify(query: String) async throws -> UnifiedSearchIntent {
        return UnifiedSearchIntent(
            searchType: .mixed,
            rawQuery: query
        )
    }
}

// MARK: - Future Foundation Models Integration

/*
 When Apple's Foundation Models become available, replace the above implementation with:
 
 import FoundationModels
 
 public actor FoundationModelsIntentClassifier {
     private let model: LanguageModel
     
     public init() async throws {
         self.model = try await LanguageModel.load()
     }
     
     public func classify(query: String) async throws -> UnifiedSearchIntent {
         let prompt = """
         Analyze this search query and extract structured parameters.
         
         Query: "\(query)"
         
         Extract:
         - search_type: "category" | "taste" | "place" | "location" | "mixed"
         - categories: array of category/cuisine names
         - tastes: array of feature/ambiance keywords
         - price_range: {min: 1-4, max: 1-4} if price mentioned
         - place_name: specific business name if mentioned
         - location_description: location/area if mentioned
         - confidence: 0.0-1.0
         
         Output valid JSON only.
         """
         
         let response = try await model.generate(
             prompt: prompt,
             format: .json,
             temperature: 0.3 // Lower temperature for more consistent extraction
         )
         
         var intent = try JSONDecoder().decode(UnifiedSearchIntent.self, from: response.data)
         intent.rawQuery = query
         return intent
     }
 }
 */


