//
//  EmbeddingCache.swift
//  Know Maps
//

import Foundation

/// Thread-safe, persistent embedding cache.
/// Stores [String: [Double]] on disk as JSON.
/// Keys are stable identifiers: fsqID, eventID, categoryName, etc.
public final class EmbeddingCache {

    public static let shared = EmbeddingCache()

    private let queue = DispatchQueue(label: "EmbeddingCacheQueue", qos: .utility)
    private var memoryCache: [String: [Double]] = [:]

    private let url: URL

    private struct CacheFile: Codable {
        let embeddings: [String: [Double]]
    }

    private init() {
        // ~/Documents/embedding-cache.json
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = docs.appendingPathComponent("embedding-cache.json")

        // Load cache if exists
        if fm.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(CacheFile.self, from: data)
                memoryCache = decoded.embeddings
                print("🧠 Loaded \(memoryCache.count) cached embeddings.")
            } catch {
                print("⚠️ Failed to load embedding cache: \(error)")
            }
        }
    }

    /// Returns cached embedding if available.
    public func get(_ key: String) -> [Double]? {
        queue.sync { memoryCache[key] }
    }

    /// Stores embedding persistently.
    public func set(_ key: String, vector: [Double]) {
        queue.async {
            self.memoryCache[key] = vector
            self.persist()
        }
    }

    private func persist() {
        let cacheFile = CacheFile(embeddings: memoryCache)
        do {
            let data = try JSONEncoder().encode(cacheFile)
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ Failed to persist embedding cache: \(error)")
        }
    }
}
