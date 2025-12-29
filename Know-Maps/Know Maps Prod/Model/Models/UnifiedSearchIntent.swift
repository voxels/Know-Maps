//
//  UnifiedSearchIntent.swift
//  Know Maps
//
//  Created on 11/26/24.
//

import Foundation
import CoreLocation

/// Represents the classified intent from a user's search query.
/// This structure is populated by FoundationModelsIntentClassifier.
public struct UnifiedSearchIntent: Codable, Sendable {
    
    // MARK: - Properties
    
    /// The primary type of search being performed
    public let searchType: SearchType
    
    /// Category names extracted from the query (e.g., ["Japanese", "Sushi"])
    public let categories: [String]?
    
    /// Taste/feature keywords (e.g., ["outdoor seating", "wifi"])
    public let tastes: [String]?
    
    /// Price range (1-4 scale, 1=cheap, 4=expensive)
    public let priceRange: PriceRange?
    
    /// Specific business name if mentioned
    public let placeName: String?
    
    /// Location description (e.g., "Golden Gate Park", "downtown")
    public let locationDescription: String?
    
    /// Target opening time extracted from the query (e.g., "7pm")
    public let openAt: String?
    
    /// Raw query text for reference
    public let rawQuery: String
    
    /// Confidence score from the classifier (0.0-1.0)
    public let confidence: Double?
    
    // MARK: - Nested Types
    
    /// The type of search being performed
    public enum SearchType: String, Codable, Sendable {
        /// Searching by category/industry (e.g., "restaurants", "coffee shops")
        case category
        
        /// Searching by features/tastes (e.g., "outdoor seating", "live music")
        case taste
        
        /// Searching for a specific place by name
        case place
        
        /// Searching by location/area
        case location
        
        /// Mixed intent (combination of the above)
        case mixed
    }
    
    /// Price range structure
    public struct PriceRange: Codable, Sendable, Sendable {
        public let min: Int // 1-4
        public let max: Int // 1-4
        
        public init(min: Int, max: Int) {
            self.min = Swift.min(Swift.max(min, 1), 4)
            self.max = Swift.min(Swift.max(max, 1), 4)
        }
        
        /// Creates a single price level
        public init(exact: Int) {
            let clamped = Swift.min(Swift.max(exact, 1), 4)
            self.min = clamped
            self.max = clamped
        }
    }
    
    // MARK: - Initialization
    
    public init(
        searchType: SearchType,
        categories: [String]? = nil,
        tastes: [String]? = nil,
        priceRange: PriceRange? = nil,
        placeName: String? = nil,
        locationDescription: String? = nil,
        openAt: String? = nil,
        rawQuery: String,
        confidence: Double? = nil
    ) {
        self.searchType = searchType
        self.categories = categories
        self.tastes = tastes
        self.priceRange = priceRange
        self.placeName = placeName
        self.locationDescription = locationDescription
        self.openAt = openAt
        self.rawQuery = rawQuery
        self.confidence = confidence
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case searchType = "search_type"
        case categories
        case tastes
        case priceRange = "price_range"
        case placeName = "place_name"
        case locationDescription = "location_description"
        case openAt = "open_at"
        case rawQuery = "raw_query"
        case confidence
    }
    
    // MARK: - Helper Methods
    
    /// Determines if this is a complex query with multiple intents
    public var isComplexQuery: Bool {
        let intentCount = [
            categories?.isEmpty == false,
            tastes?.isEmpty == false,
            placeName?.isEmpty == false,
            locationDescription?.isEmpty == false,
            priceRange != nil
        ].filter { $0 }.count
        
        return intentCount > 1
    }
    
    /// Returns a user-friendly description of the intent
    public var intentDescription: String {
        switch searchType {
        case .category:
            if let categories = categories, !categories.isEmpty {
                return "Searching for \(categories.joined(separator: ", "))"
            }
            return "Category search"
        case .taste:
            if let tastes = tastes, !tastes.isEmpty {
                return "Looking for places with \(tastes.joined(separator: ", "))"
            }
            return "Feature search"
        case .place:
            if let name = placeName {
                return "Searching for \(name)"
            }
            return "Place name search"
        case .location:
            if let location = locationDescription {
                return "Searching near \(location)"
            }
            return "Location search"
        case .mixed:
            return "Complex search"
        }
    }
    
    /// Returns an emoji icon representing the search type
    public var icon: String {
        switch searchType {
        case .category:
            return "🏷️"
        case .taste:
            return "✨"
        case .place:
            return "📍"
        case .location:
            return "🌍"
        case .mixed:
            return "🔍"
        }
    }
}
