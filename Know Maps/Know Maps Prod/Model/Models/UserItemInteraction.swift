//
//  UserItemInteraction.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/4/25.
//

// UserItemInteraction.swift

import Foundation

public struct UserItemInteraction: Codable {
    public let userID: String
    public let itemID: String
    public let timestamp: Date
    
    /// A numeric signal: explicit rating, click=1, skip=0, etc.
    public let score: Double
    
    /// Optional context: where did this happen (search results, detail page, etc.)
    public let context: String?
    
    public init(
        userID: String,
        itemID: String,
        timestamp: Date = Date(),
        score: Double,
        context: String? = nil
    ) {
        self.userID = userID
        self.itemID = itemID
        self.timestamp = timestamp
        self.score = score
        self.context = context
    }
}
