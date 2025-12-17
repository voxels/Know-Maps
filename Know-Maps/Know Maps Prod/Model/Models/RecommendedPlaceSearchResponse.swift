//
//  RecommendedPlaceResponse.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/24/24.
//

import Foundation

public struct RecommendedPlaceSearchResponse: Equatable, Hashable, Sendable {
    let uuid:String = UUID().uuidString
    let fsqID:String
    let name:String
    let categories:[String]
    let latitude:Double
    let longitude:Double
    let neighborhood:String
    let address:String
    let country:String
    let city:String
    let state:String
    let postCode:String
    let formattedAddress:String
    let photo:String?
    let aspectRatio:Float?
    let photos:[String]
    let tastes:[String]
}

extension RecommendedPlaceSearchResponse {

    /// Converts a FSQ place search result into ItemMetadata for the advanced recommender.
    func toItemMetadata() -> ItemMetadata {

        // High-quality description block
        let description = """
        \(name) located at \(formattedAddress).
        Neighborhood: \(neighborhood). \
        Categories: \(categories.joined(separator: ", ")). \
        Tastes: \(tastes.joined(separator: ", ")).
        """

        // Canonical combined location
        let locationString = "\(city), \(state), \(country)"

        // FSQ does not provide price here → assume nil
        let priceTier: Double? = nil

        return ItemMetadata(
            id: fsqID,
            title: name,
            descriptionText: description,
            styleTags: tastes,
            categories: categories,
            location: locationString,
            price: priceTier
        )
    }
}
