//
//  EmbeddingCache.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/14/24.
//

import Foundation

/// Simple in-memory cache for embeddings.
/// Not thread-safe, but accessed from a single queue in MiniLMEmbeddingClient.
final class EmbeddingCache {
    static let shared = EmbeddingCache()
    
    private var cache: [String: [Double]] = [:]
    private let maxCacheSize = 1000 // Limit cache size to prevent excessive memory usage
    
    private init() {}
    
    func get(_ key: String) -> [Double]? {
        return cache[key]
    }
    
    func set(_ key: String, vector: [Double]) {
        if cache.count >= maxCacheSize {
            cache.removeFirst() // Simple eviction strategy
        }
        cache[key] = vector
    }
}