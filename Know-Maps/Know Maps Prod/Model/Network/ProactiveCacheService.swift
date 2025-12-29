import Foundation
import SwiftData
import CloudKit

@MainActor public final class ProactiveCacheService {
    private let modelContext: ModelContext
    private let analyticsManager: AnalyticsService
    
    public init(modelContext: ModelContext, analyticsManager: AnalyticsService) {
        self.modelContext = modelContext
        self.analyticsManager = analyticsManager
    }
    
    /// Stores or updates a proactive cache entry for a given identity.
    public func store(identity: String, data: Data) {
        let fetchDescriptor = FetchDescriptor<ProactiveCacheEntry>(
            predicate: #Predicate { $0.identity == identity }
        )
        
        do {
            if let existing = try modelContext.fetch(fetchDescriptor).first {
                existing.data = data
                existing.timestamp = Date()
            } else {
                let newEntry = ProactiveCacheEntry(identity: identity, data: data)
                modelContext.insert(newEntry)
            }
            try modelContext.save()
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: ["context": "ProactiveCacheService.store", "identity": identity])
        }
    }
    
    /// Retrieves a cached entry if it exists and is not expired (e.g., 24 hours).
    public func retrieve(identity: String, maxAge: TimeInterval = 86400) -> Data? {
        let fetchDescriptor = FetchDescriptor<ProactiveCacheEntry>(
            predicate: #Predicate { $0.identity == identity }
        )
        
        do {
            if let entry = try modelContext.fetch(fetchDescriptor).first {
                let age = Date().timeIntervalSince(entry.timestamp)
                if age < maxAge {
                    return entry.data
                } else {
                    // Optionally cleanup expired entry
                    modelContext.delete(entry)
                    try? modelContext.save()
                }
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: ["context": "ProactiveCacheService.retrieve", "identity": identity])
        }
        return nil
    }
    
    /// Deletes a specific entry.
    public func remove(identity: String) {
        let fetchDescriptor = FetchDescriptor<ProactiveCacheEntry>(
            predicate: #Predicate { $0.identity == identity }
        )
        
        do {
            if let entry = try modelContext.fetch(fetchDescriptor).first {
                modelContext.delete(entry)
                try modelContext.save()
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: ["context": "ProactiveCacheService.remove", "identity": identity])
        }
    }

    /// Clears all proactive cache entries.
    public func clearAll() {
        do {
            try modelContext.delete(model: ProactiveCacheEntry.self)
            try modelContext.save()
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: ["context": "ProactiveCacheService.clearAll"])
        }
    }
}
