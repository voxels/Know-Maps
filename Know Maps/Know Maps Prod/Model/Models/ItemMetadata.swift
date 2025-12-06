//
//  ItemMetadata.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/4/25.
//

// ItemMetadata.swift

import Foundation

public struct ItemMetadata: Identifiable, Hashable {
    public let id: String           // fsqID, or "Barbican–Temporal Debris"
    public let title: String        // Human readable name
    public let descriptionText: String?
    public let styleTags: [String]  // e.g. ["cyberpunk", "museum"]
    public let categories: [String] // e.g. taste/industry categories
    public let location: String?    // "London, England"
    public let price: Double?       // 0.0, 21.5, etc.
    
    public init(
        id: String,
        title: String,
        descriptionText: String? = nil,
        styleTags: [String] = [],
        categories: [String] = [],
        location: String? = nil,
        price: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.styleTags = styleTags
        self.categories = categories
        self.location = location
        self.price = price
    }
}
