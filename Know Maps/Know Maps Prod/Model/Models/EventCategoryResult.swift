//
//  EventCategoryResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/4/25.
//

import Foundation

public struct EventCategoryResult {
    public let venueName: String             // "Barbican"
    public let exhibitionTitle: String       // "Temporal Debris: and the Machine"
    public let style: String                 // "cyberpunk", "academic", ...
    public let price: Double                 // 0.0, 21.5, etc.
    public let latitude: Double?
    public let longitude: Double?
    
    // You can add more fields if you want:
    public let location: String?             // "London, England"
    public let about: String?                // long descriptive text
    public let startDate: Date?
    public let endDate: Date?
    public let link: URL?
    
    public init(
        venueName: String,
        exhibitionTitle: String,
        style: String,
        price: Double,
        latitude: Double? = nil,
        longitude: Double? = nil,
        location: String? = nil,
        about: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        link: URL? = nil
    ) {
        self.venueName = venueName
        self.exhibitionTitle = exhibitionTitle
        self.style = style
        self.price = price
        self.latitude = latitude
        self.longitude = longitude
        self.location = location
        self.about = about
        self.startDate = startDate
        self.endDate = endDate
        self.link = link
    }
}

extension EventCategoryResult: RecommendationCategoryConvertible {
    
    // e.g. "Barbican – Temporal Debris: and the Machine"
    public var recommenderIdentity: String {
        "\(venueName) – \(exhibitionTitle)"
    }
    
    // We’ll use the style column as the attribute for now.
    public var recommenderAttribute: String {
        style
    }
    
    // VERY SIMPLE rating heuristic to start with.
    // You should tweak this for your domain.
    public var recommenderRating: Double {
        // Example:
        // - Free events rated higher
        // - Paid events slightly lower
        if price == 0 {
            return 1.0
        } else if price <= 10 {
            return 0.9
        } else if price <= 25 {
            return 0.8
        } else {
            return 0.7
        }
    }
}

extension EventCategoryResult {
    func toItemMetadata() -> ItemMetadata {
        let desc = [
            about,
            location.map { "Located at \($0)." },
            latitude != nil && longitude != nil ? "Coordinates: latitude \(latitude!), longitude \(longitude!)." : nil
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        return ItemMetadata(
            id: recommenderIdentity,
            title: exhibitionTitle,
            descriptionText: desc,
            styleTags: [style],
            categories: [venueName],
            location: location,
            price: price
        )
    }
}
