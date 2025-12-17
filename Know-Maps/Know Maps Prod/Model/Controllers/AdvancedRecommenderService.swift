//
//  DefaultAdvancedRecommenderService.swift
//  Know Maps
//

import Foundation
import CoreML

@MainActor
public protocol AdvancedRecommender {
    func userEmbedding(
        userID: String,
        categoryResults: [CategoryResult],
        eventResults: [EventCategoryResult],
        interactions: [UserItemInteraction]
    ) async throws -> [Double]

    func itemEmbedding(for item: ItemMetadata) async throws -> [Double]

    func rankItems(
        for userID: String,
        items: [ItemMetadata],
        categoryResults: [CategoryResult],
        eventResults: [EventCategoryResult],
        interactions: [UserItemInteraction]
    ) async throws -> [(item: ItemMetadata, score: Double)]
}

@MainActor
public final class DefaultAdvancedRecommenderService: AdvancedRecommender {
    private let textEmbedder: MiniLMEmbeddingClient
    private let scorerModel: HybridRecommenderModel

    public init(scorerModel: HybridRecommenderModel) {
        self.textEmbedder = MiniLMEmbeddingClient.shared
        self.scorerModel = scorerModel
    }

    // --------------------------------------------------------------------
    // MARK: Public API
    // --------------------------------------------------------------------

    public func userEmbedding(
        userID: String,
        categoryResults: [CategoryResult],
        eventResults: [EventCategoryResult],
        interactions: [UserItemInteraction]
    ) async throws -> [Double] {
        try await buildUserEmbedding(
            userID: userID,
            categoryResults: categoryResults,
            eventResults: eventResults,
            interactions: interactions
        )
    }

    public func itemEmbedding(for item: ItemMetadata) async throws -> [Double] {
        try await buildItemEmbedding(item)
    }

    public func rankItems(
        for userID: String,
        items: [ItemMetadata],
        categoryResults: [CategoryResult],
        eventResults: [EventCategoryResult],
        interactions: [UserItemInteraction]
    ) async throws -> [(item: ItemMetadata, score: Double)]{

        let userVec = try await userEmbedding(
            userID: userID,
            categoryResults: categoryResults,
            eventResults: eventResults,
            interactions: interactions
        )

        var results: [(ItemMetadata, Double)] = []
        results.reserveCapacity(items.count)

        for item in items {
            let itemVec = try await itemEmbedding(for: item)
            let score = try score(userEmbedding: userVec, itemEmbedding: itemVec)
            results.append((item, score))
        }

        return results.sorted { $0.1 > $1.1 }
    }
}

// --------------------------------------------------------------------
// MARK: ITEM EMBEDDINGS
// --------------------------------------------------------------------

extension DefaultAdvancedRecommenderService {

   @MainActor fileprivate func buildItemEmbedding(_ item: ItemMetadata) async throws -> [Double] {
        let key = "item::" + item.id

        if let cached = EmbeddingCache.shared.get(key) {
            return cached
        }
        
        var parts = [item.title]

        if let desc = item.descriptionText { parts.append(desc) }
        if !item.styleTags.isEmpty { parts.append("Styles: " + item.styleTags.joined(separator: ", ")) }
        if !item.categories.isEmpty { parts.append("Categories: " + item.categories.joined(separator: ", ")) }
        if let loc = item.location { parts.append("Location: \(loc)") }
        if let price = item.price { parts.append("Price: \(price)") }

        let text = parts.joined(separator: " • ")
        let vec = try await textEmbedder.embed(text)
        EmbeddingCache.shared.set(key, vector: vec)
        return vec
    }
}

// --------------------------------------------------------------------
// MARK: USER EMBEDDING
// --------------------------------------------------------------------

extension DefaultAdvancedRecommenderService {
    fileprivate func buildUserEmbedding(
        userID: String,
        categoryResults: [CategoryResult],
        eventResults: [EventCategoryResult],
        interactions: [UserItemInteraction]
    ) async throws -> [Double] {

        
        
        var vectors: [[Double]] = []
        var weights: [Double] = []

        // 1) Category preferences
        for result in categoryResults {
            let text = "Category preference: \(result.parentCategory)"
            let v = try await textEmbedder.embed(text)
            let w = max(result.rating, 0.0)
            vectors.append(v)
            weights.append(w)
        }

        // 2) Event preferences
        for event in eventResults {
            let text = "Event preference: \(event.style) at \(event.venueName)"
            let v = try await textEmbedder.embed(text)
            let w = max(event.recommenderRating, 0.0)
            vectors.append(v)
            weights.append(w)
        }

        // 3) Interaction history
        for interaction in interactions where interaction.userID == userID {
            guard let item = ItemLookup.shared.item(for: interaction.itemID) else { continue }
            let v = try await buildItemEmbedding(item)
            let w = max(interaction.score, 0.0)
            vectors.append(v)
            weights.append(w)
        }

        return weightedAverage(vectors: vectors, weights: weights)
    }

    private func weightedAverage(vectors: [[Double]], weights: [Double]) -> [Double] {
        guard !vectors.isEmpty else { return [] }
        let dim = vectors[0].count

        var acc = Array(repeating: 0.0, count: dim)
        var total = 0.0

        for (v, w) in zip(vectors, weights) {
            for i in 0..<dim { acc[i] += v[i] * w }
            total += w
        }

        guard total > 0 else { return acc }
        return normalize(acc.map { $0 / total })
    }

    private func normalize(_ v: [Double]) -> [Double] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }
}

// --------------------------------------------------------------------
// MARK: SCORING (CoreML Hybrid Model)
// --------------------------------------------------------------------

extension DefaultAdvancedRecommenderService {

    private func score(
        userEmbedding: [Double],
        itemEmbedding: [Double]
    ) throws -> Double {
        return scorerModel.score(
            userEmbedding: userEmbedding,
            itemEmbedding: itemEmbedding
        )
    }
}
