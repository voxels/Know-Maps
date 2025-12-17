//
//  RecommendationData.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/9/24.
//
import Foundation
import SwiftData

@Model
public final class RecommendationData: Identifiable, Hashable, Equatable, Codable {
    public var id: UUID = UUID()
    var recordId: String = UUID().uuidString
    var identity: String = ""
    var attributes: [String] = []
    var reviews: [String] = []
    var attributeRatings: [String: Double] = [:]
    
    public init(
        id: UUID = UUID(),
        recordId: String,
        identity: String,
        attributes: [String],
        reviews: [String],
        attributeRatings: [String: Double]
    ) {
        self.id = id
        self.recordId = recordId
        self.identity = identity
        self.attributes = attributes
        self.reviews = reviews
        self.attributeRatings = attributeRatings
    }
    
    public func setRecordId(to string: String) {
        recordId = string
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id
        case recordId
        case identity
        case attributes
        case reviews
        case attributeRatings
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recordId, forKey: .recordId)
        try container.encode(identity, forKey: .identity)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(reviews, forKey: .reviews)
        try container.encode(attributeRatings, forKey: .attributeRatings)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let recordId = try container.decode(String.self, forKey: .recordId)
        let identity = try container.decode(String.self, forKey: .identity)
        let attributes = try container.decode([String].self, forKey: .attributes)
        let reviews = try container.decode([String].self, forKey: .reviews)
        let attributeRatings = try container.decode([String: Double].self, forKey: .attributeRatings)
        
        self.init(
            id: id,
            recordId: recordId,
            identity: identity,
            attributes: attributes,
            reviews: reviews,
            attributeRatings: attributeRatings
        )
    }
}
