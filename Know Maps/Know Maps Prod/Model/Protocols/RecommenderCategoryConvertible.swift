//
//  RecommenderCategoryConvertible.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/4/25.
//

// RecommenderCategoryConvertible.swift

import Foundation

/// Anything that can be turned into a single (identity, attribute, rating) row
/// for the recommender.
public protocol RecommendationCategoryConvertible {
    /// The thing being rated (place, category, event, etc.)
    var recommenderIdentity: String { get }

    /// The attribute/feature being rated (e.g. taste tag, style, etc.)
    var recommenderAttribute: String { get }

    /// The numeric rating for this (identity, attribute) pair.
    var recommenderRating: Double { get }
}
