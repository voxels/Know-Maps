//
//  FoundationModelsIntentClassifier.swift
//  Know Maps
//
//  Created on 11/26/24.
//

import Foundation
import NaturalLanguage

/// Classifies user search queries into structured intents using on-device intelligence.
/// This replaces the simple keyword matching in AssistiveChatHostService with
/// context-aware understanding.
///
/// Note: This is a placeholder implementation using NLTagger until Apple's
/// Foundation Models framework becomes available. The structure is designed
/// to be drop-in replaceable with the actual FoundationModels API.
public actor FoundationModelsIntentClassifier {
    
    // MARK: - Properties
    
    private let tagger: NLTagger
    private let categoryKeywords: [String: [String]]
    
    // MARK: - Initialization
    
    public init() {
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        
        // Common category keywords for classification
        self.categoryKeywords = [
            "restaurant": ["restaurant", "dining", "food", "eat", "meal"],
            "coffee": ["coffee", "cafe", "espresso", "latte"],
            "bar": ["bar", "pub", "tavern", "brewery", "drinks"],
            "shopping": ["shop", "store", "boutique", "mall"],
            "entertainment": ["theater", "cinema", "movie", "show"],
            "fitness": ["gym", "fitness", "yoga", "workout"]
        ]
    }
    
    // MARK: - Public Methods
    
    /// Classifies a search query into a structured intent.
    ///
    /// - Parameter query: The raw user search query
    /// - Returns: A UnifiedSearchIntent with extracted parameters
    public func classify(query: String) async throws -> UnifiedSearchIntent {
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract components
        let extractedCategories = extractCategories(from: lowercaseQuery)
        let extractedTastes = extractTastes(from: lowercaseQuery)
        let priceRange = extractPriceRange(from: lowercaseQuery)
        let placeName = extractPlaceName(from: query) // Use original case
        let location = extractLocation(from: lowercaseQuery)
        
        // Determine primary search type
        let searchType = determineSearchType(
            categories: extractedCategories,
            tastes: extractedTastes,
            placeName: placeName,
            location: location
        )
        
        return UnifiedSearchIntent(
            searchType: searchType,
            categories: extractedCategories,
            tastes: extractedTastes,
            priceRange: priceRange,
            placeName: placeName,
            locationDescription: location,
            rawQuery: query,
            confidence: 0.85 // Placeholder confidence score
        )
    }
    
    // MARK: - Private Methods
    
    /// Extracts category names from the query
    private func extractCategories(from query: String) -> [String]? {
        var categories: [String] = []
        
        // Check for direct category matches
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if query.contains(keyword) {
                    categories.append(category.capitalized)
                    break
                }
            }
        }
        
        // Common food categories
        let foodKeywords = [
            "sushi", "pizza", "burger", "mexican", "chinese",
            "italian", "thai", "indian", "japanese", "french"
        ]
        
        for food in foodKeywords {
            if query.contains(food) {
                categories.append(food.capitalized)
            }
        }
        
        return categories.isEmpty ? nil : Array(Set(categories))
    }
    
    /// Extracts taste/feature keywords from the query
    private func extractTastes(from query: String) -> [String]? {
        let tasteKeywords = [
            "outdoor seating": ["outdoor", "patio", "terrace"],
            "wifi": ["wifi", "internet", "laptop"],
            "live music": ["live music", "band", "performance"],
            "romantic": ["romantic", "date", "intimate"],
            "family-friendly": ["family", "kids"],
            "quiet": ["quiet", "peaceful", "calm"],
            "cozy": ["cozy", "comfortable"],
            "spacious": ["spacious", "large", "roomy"]
        ]
        
        var tastes: [String] = []
        
        for (taste, keywords) in tasteKeywords {
            for keyword in keywords {
                if query.contains(keyword) {
                    tastes.append(taste)
                    break
                }
            }
        }
        
        return tastes.isEmpty ? nil : Array(Set(tastes))
    }
    
    /// Extracts price range from the query
    private func extractPriceRange(from query: String) -> UnifiedSearchIntent.PriceRange? {
        // Cheap/affordable
        if query.contains("cheap") || query.contains("affordable") || query.contains("budget") {
            return UnifiedSearchIntent.PriceRange(min: 1, max: 2)
        }
        
        // Mid-range
        if query.contains("moderate") || query.contains("mid-range") {
            return UnifiedSearchIntent.PriceRange(min: 2, max: 3)
        }
        
        // Expensive/upscale
        if query.contains("expensive") || query.contains("upscale") || query.contains("luxury") || query.contains("fine dining") {
            // Check for negation
            if query.contains("not expensive") || query.contains("not that expensive") {
                return UnifiedSearchIntent.PriceRange(min: 1, max: 3)
            }
            return UnifiedSearchIntent.PriceRange(min: 3, max: 4)
        }
        
        return nil
    }
    
    /// Extracts a specific place name using NLTagger
    private func extractPlaceName(from query: String) -> String? {
        tagger.string = query
        var placeName: String?
        
        tagger.enumerateTags(
            in: query.startIndex..<query.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, range in
            if tag == .organizationName || tag == .placeName {
                placeName = String(query[range])
                return false // Stop after first match
            }
            return true
        }
        
        return placeName
    }
    
    /// Extracts location description from the query
    private func extractLocation(from query: String) -> String? {
        // Look for "near", "around", "in", "at" patterns
        let locationPatterns = [
            "near ",
            "around ",
            "in ",
            "at ",
            "close to "
        ]
        
        for pattern in locationPatterns {
            if let range = query.range(of: pattern) {
                let afterPattern = String(query[range.upperBound...])
                // Extract until next comma or end
                if let commaRange = afterPattern.range(of: ",") {
                    return String(afterPattern[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    return afterPattern.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return nil
    }
    
    /// Determines the primary search type based on extracted components
    private func determineSearchType(
        categories: [String]?,
        tastes: [String]?,
        placeName: String?,
        location: String?
    ) -> UnifiedSearchIntent.SearchType {
        let componentCount = [
            categories?.isEmpty == false,
            tastes?.isEmpty == false,
            placeName != nil,
            location != nil
        ].filter { $0 }.count
        
        // If multiple components, it's a mixed query
        if componentCount > 1 {
            return .mixed
        }
        
        // Single component classification
        if placeName != nil {
            return .place
        }
        
        if location != nil {
            return .location
        }
        
        if tastes?.isEmpty == false {
            return .taste
        }
        
        if categories?.isEmpty == false {
            return .category
        }
        
        // Default to category search
        return .category
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
