//
//  ItemLookup.swift
//  Know Maps
//
//  Created by ChatGPT on 12/4/25.
//

import Foundation

/// Global registry for all `ItemMetadata` objects used by the recommender.
/// This includes real venues, exhibitions, events, and synthetic items.
public final class ItemLookup {

    // MARK: - Singleton
    public static let shared = ItemLookup()

    // MARK: - Storage
    /// Internal registry: itemID → ItemMetadata
    private var registry: [String: ItemMetadata] = [:]

    private init() {}

    // MARK: - Public API

    /// Returns the item metadata for an ID (e.g., fsqID or exhibition ID).
    public func item(for id: String) -> ItemMetadata? {
        registry[id]
    }

    /// Registers a single item. Existing items with same ID are replaced.
    public func register(_ item: ItemMetadata) {
        registry[item.id] = item
    }

    /// Registers an entire array of items. Existing matches are overwritten.
    public func registerAll(_ items: [ItemMetadata]) {
        for item in items {
            registry[item.id] = item
        }
    }

    /// Returns everything currently registered.
    public func allItems() -> [ItemMetadata] {
        Array(registry.values)
    }

    /// Clears the registry — usually only used during debugging or full refresh.
    public func clear() {
        registry.removeAll()
    }
}
