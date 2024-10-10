//
//  PersonalizedSearchSection.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/10/24.
//

import Foundation
import AppIntents

public enum PersonalizedSearchSection: String, Hashable, CaseIterable, AppEnum  {
    
    case food = "Food"
    case drinks = "Drinks"
    case coffee = "Coffee"
    case shops = "Shopping"
    case arts = "Arts"
    case outdoors = "Outdoors"
    case sights = "Sightseeing"
    case trending = "Trending places"
    case topPicks = "Popular places"

    // Implement required properties for AppEnum
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mood")

    public static var caseDisplayRepresentations: [PersonalizedSearchSection: DisplayRepresentation] = [
        .food: DisplayRepresentation(title: "Food"),
        .drinks: DisplayRepresentation(title: "Drinks"),
        .coffee: DisplayRepresentation(title: "Coffee"),
        .shops: DisplayRepresentation(title: "Shopping"),
        .arts: DisplayRepresentation(title: "Arts"),
        .outdoors: DisplayRepresentation(title: "Outdoors"),
        .sights: DisplayRepresentation(title: "Sightseeing"),
        .trending: DisplayRepresentation(title: "Trending Places"),
        .topPicks: DisplayRepresentation(title: "Popular Places")
    ]

    // Existing methods (if still needed)
    public func key() -> String {
        switch self {
        case .food:
            return "food"
        case .drinks:
            return "drinks"
        case .coffee:
            return "coffee"
        case .shops:
            return "shops"
        case .arts:
            return "arts"
        case .outdoors:
            return "outdoors"
        case .sights:
            return "sights"
        case .trending:
            return "trending"
        case .topPicks:
            return "topPicks"
        @unknown default:
            return "none"
        }
    }

    public func categoryResult() -> CategoryResult {
        let chatResult = ChatResult(
            index: 0,
            identity: self.rawValue,
            title: rawValue,
            list: self.rawValue,
            icon: "",
            rating: 1,
            section: self,
            placeResponse: nil,
            recommendedPlaceResponse: nil
        )
        let categoryResult = CategoryResult(
            identity: self.rawValue,
            parentCategory: rawValue,
            list: self.rawValue,
            icon: "",
            rating: 1,
            section: self,
            categoricalChatResults: [chatResult]
        )
        return categoryResult
    }
    
    // MARK: - DynamicOptionsProvider Conformance
    public func results() async throws -> [PersonalizedSearchSection] {
        return PersonalizedSearchSection.allCases
    }
}

public struct PersonalizedSearchSectionOptionsProvider : DynamicOptionsProvider {
    // MARK: - DynamicOptionsProvider Conformance
    public func results() async throws -> [PersonalizedSearchSection] {
        return PersonalizedSearchSection.allCases
    }
}
