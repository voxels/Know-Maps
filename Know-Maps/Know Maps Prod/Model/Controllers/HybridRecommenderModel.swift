//
//  HybridRecommenderModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/4/25.
//

import Foundation

/// Temporary stub for a future learned ranking model.
/// Right now it just computes cosine similarity between user and item embeddings.
public final class HybridRecommenderModel {

    public init() {}

    /// Returns a score in [-1, 1] based on cosine similarity.
    /// Later, this can be replaced by a CoreML model call.
    public func score(
        userEmbedding: [Double],
        itemEmbedding: [Double]
    ) -> Double {
        guard !userEmbedding.isEmpty,
              userEmbedding.count == itemEmbedding.count
        else {
            return 0.0
        }

        let dot = zip(userEmbedding, itemEmbedding).map(*).reduce(0.0, +)
        let normU = sqrt(userEmbedding.map { $0 * $0 }.reduce(0.0, +))
        let normI = sqrt(itemEmbedding.map { $0 * $0 }.reduce(0.0, +))

        guard normU > 0, normI > 0 else { return 0.0 }
        return dot / (normU * normI)
    }
}
