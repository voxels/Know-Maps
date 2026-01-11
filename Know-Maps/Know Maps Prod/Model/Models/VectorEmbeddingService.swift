//
//  VectorEmbeddingService.swift
//  Know Maps
//
//  Created on 11/26/24.
//

import Foundation
import NaturalLanguage

/// Service that provides semantic similarity scoring using vector embeddings.
/// Enables "meaning-based" search that understands synonyms and related concepts.
///
/// Example:
/// - Query "cozy date spot" matches places with "romantic", "intimate", "quiet"
/// - Query "work from" matches places with "wifi", "outlets", "laptop-friendly"
public class VectorEmbeddingService: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let embedding: NLEmbedding?
    
    // MARK: - Initialization
    
    public init() {
        // Use Apple's pre-trained sentence embedding model for English
        if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) {
            self.embedding = sentenceEmbedding
        } else {
            print("KnowMaps: Failed to load sentence embedding model. Semantic search will be disabled.")
            self.embedding = nil
        }
    }
    
    // MARK: - Public Methods
    
    /// Calculates semantic similarity between a query and place description.
    ///
    /// - Parameters:
    ///   - query: User's search query (e.g., "cozy coffee shop")
    ///   - placeDescription: Combined text from place (name + categories + description)
    /// - Returns: Similarity score from 0.0 (no match) to 1.0 (perfect match)
    public func semanticScore(query: String, placeDescription: String) -> Double {
        guard let embedding = embedding,
              let queryVector = embedding.vector(for: query),
              let placeVector = embedding.vector(for: placeDescription) else {
            return 0.0
        }
        return cosineSimilarity(queryVector, placeVector)
    }
    
    /// Batch version for scoring multiple places efficiently.
    ///
    /// - Parameters:
    ///   - query: User's search query
    ///   - placeDescriptions: Array of place descriptions to score
    /// - Returns: Array of similarity scores in the same order as input
    public func batchSemanticScores(query: String, placeDescriptions: [String]) -> [Double] {
        guard let embedding = embedding,
              let queryVector = embedding.vector(for: query) else {
            return Array(repeating: 0.0, count: placeDescriptions.count)
        }
        
        return placeDescriptions.map { description in
            guard let placeVector = embedding.vector(for: description) else {
                return 0.0
            }
            return cosineSimilarity(queryVector, placeVector)
        }
    }
    
    /// Checks if two terms are semantically similar (e.g., "cheap" and "affordable")
    ///
    /// - Parameters:
    ///   - term1: First term
    ///   - term2: Second term
    ///   - threshold: Minimum similarity score (default: 0.7)
    /// - Returns: True if terms are semantically similar
    public func areSimilar(_ term1: String, _ term2: String, threshold: Double = 0.7) -> Bool {
        guard let embedding = embedding,
              let vector1 = embedding.vector(for: term1),
              let vector2 = embedding.vector(for: term2) else {
            return false
        }
        return cosineSimilarity(vector1, vector2) >= threshold
    }
    
    // MARK: - Private Methods
    
    /// Calculates cosine similarity between two vectors.
    ///
    /// Cosine similarity measures the angle between vectors, ranging from -1 to 1.
    /// For embeddings, values closer to 1 indicate higher similarity.
    ///
    /// - Parameters:
    ///   - vectorA: First vector
    ///   - vectorB: Second vector
    /// - Returns: Cosine similarity score
    private func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else {
            return 0.0
        }
        
        let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
        let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0, magnitudeB > 0 else {
            return 0.0
        }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    /// Combines place information into a searchable description string.
    ///
    /// - Parameters:
    ///   - name: Place name
    ///   - categories: Array of category names
    ///   - description: Optional place description
    /// - Returns: Combined string for semantic matching
    public func buildPlaceDescription(name: String, categories: [String], description: String?) -> String {
        var components = [name]
        components.append(contentsOf: categories)
        if let description = description, !description.isEmpty {
            components.append(description)
        }
        return components.joined(separator: " ")
    }
}
