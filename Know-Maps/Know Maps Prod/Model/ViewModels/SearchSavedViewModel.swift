//
//  SearchSavedViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation
import ConcurrencyExtras

@MainActor
@Observable
public final class SearchSavedViewModel : Sendable {
    
    public static let shared = SearchSavedViewModel()
    
    public var filters: [String:AnyHashableSendable] {
        get {
            retrieveFiltersFromUserDefaults()
        }
        
        set{
            saveFiltersToUserDefaults(filters: newValue)
        }
    }
    
    public var editingRecommendationWeightResult: CategoryResult?
    
    func saveFiltersToUserDefaults(filters: [String: AnyHashableSendable]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: filters, options: [])
            UserDefaults.standard.set(data, forKey: "savedFilters")
        } catch {
            print("Error saving filters: \(error.localizedDescription)")
        }
    }
    
    func retrieveFiltersFromUserDefaults() -> [String: AnyHashableSendable] {
        if let data = UserDefaults.standard.data(forKey: "savedFilters") {
            do {
                if let filters = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyHashableSendable] {
                    return filters
                }
            } catch {
                print("Error retrieving filters: \(error.localizedDescription)")
            }
        }
        return [:]
    }
    
    // MARK: - Helper Functions
    
    func updateRating(for result: CategoryResult, rating: Double,  cacheManager:CacheManager, modelController:ModelController) {
        Task(priority: .userInitiated) {
            do {
                await addTaste(
                    parent: result.id, rating:rating,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
                
                await addCategory(parent: result.id, rating: rating, cacheManager: cacheManager, modelController: modelController)
                
                try await changeRating(rating: rating, for: result.identity, cacheManager: cacheManager, modelController: modelController)
                editingRecommendationWeightResult = nil
                await cacheManager.refreshCachedTastes()
                await cacheManager.refreshCachedCategories()
            } catch {
                print(error)
            }
        }
    }
    
    // Add Location
    func addLocation(parent: LocationResult, location: CLLocation, cacheManager: CacheManager, modelController: ModelController) async throws {
        do {
            // Create a new UserCachedRecord for the location
            let userRecord = UserCachedRecord(
                id:UUID(),
                recordId:UUID().uuidString,
                group: "Location",
                identity: cacheManager.cachedLocationIdentity(for: location),
                title: parent.locationName,
                icons: "",
                list: "Places",
                section:PersonalizedSearchSection.topPicks.rawValue,
                rating: 1
            )
            
            // Store the record in the local cache and CloudKit
            _ = try await cacheManager.cloudCacheService.storeUserCachedRecord(recordId: userRecord.recordId,
                group: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title,
                icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section,
                rating: userRecord.rating
            )
            
            // Refresh the cached locations after adding the new location
            await cacheManager.refreshCachedLocations()
        } catch {
            // Log any errors using the analytics manager
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            throw error
        }
    }
    
    // Add Category
    func addPlace(parent: ChatResult.ID, rating:Double, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let placeChatResult = await modelController.placeChatResult(for: parent), let placeResponse = placeChatResult.placeResponse, !cacheManager.cachedPlaces(contains: placeChatResult.title) else {
            return
        }

        do {
            // Create a new UserCachedRecord for the category
            let userRecord = UserCachedRecord(
                id:UUID(),
                recordId: UUID().uuidString,
                group: "Place",
                identity: placeResponse.fsqID,
                title: placeChatResult.title,
                icons: "",
                list: placeChatResult.list,
                section: placeChatResult.section.rawValue,
                rating: rating
            )
            
            // Store the record in the local cache and CloudKit
            _ = try await cacheManager.cloudCacheService.storeUserCachedRecord(recordId: userRecord.recordId,
                group:userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title,
                icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section,
                rating: userRecord.rating
            )
            
            // Refresh the cached categories after adding the new category
            await cacheManager.refreshCachedPlaces()
            try await cacheManager.refreshCache()
        } catch {
            // Log any errors with the analytics manager
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    /// Batch add multiple industry categories by their `CategoryResult.ID`s.
    /// - Parameters:
    ///   - parents: A list of `CategoryResult.ID` values to add.
    ///   - rating: The rating to assign to each added category.
    ///   - cacheManager: Cache manager used to persist and refresh cached data.
    ///   - modelController: Model controller for analytics and lookups.
    public func addCategories(
        parents: [CategoryResult.ID],
        rating: Double,
        cacheManager: CacheManager,
        modelController: ModelController
    ) async {
        // Deduplicate IDs to avoid redundant work
        let uniqueParents = Array(Set(parents))
        guard !uniqueParents.isEmpty else { return }

        // Iterate sequentially to avoid CK write-throttle collisions
        for parent in uniqueParents {
            await addCategory(
                parent: parent,
                rating: rating,
                cacheManager: cacheManager,
                modelController: modelController
            )
        }

        // Refresh caches once at the end to minimize work
        await cacheManager.refreshCachedCategories()
        do {
            try await cacheManager.refreshCache()
        } catch {
            await modelController.analyticsManager.trackError(
                error: error,
                additionalInfo: ["context": "SearchSavedViewModel.addCategories.refreshCache"]
            )
        }
    }

    // Add Category
    func addCategory(parent: CategoryResult.ID, rating:Double, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let industryCategoryResult = await modelController.industryCategoryResult(for: parent), !cacheManager.cachedCategories(contains: industryCategoryResult.parentCategory) else {
            return
        }

        do {
            // Create a new UserCachedRecord for the category
            let userRecord = UserCachedRecord(
                id:UUID(),
                recordId: UUID().uuidString,
                group: "Category",
                identity: industryCategoryResult.parentCategory,
                title: industryCategoryResult.parentCategory,
                icons: "",
                list: industryCategoryResult.list,
                section: industryCategoryResult.section.rawValue,
                rating: rating
            )
            
            // Store the record in the local cache and CloudKit
            _ = try await cacheManager.cloudCacheService.storeUserCachedRecord(recordId: userRecord.recordId,
                group:userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title,
                icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section,
                rating: userRecord.rating
            )
            
            // Refresh the cached categories after adding the new category
            await cacheManager.refreshCachedCategories()
            try await cacheManager.refreshCache()
        } catch {
            // Log any errors with the analytics manager
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Remove Category
    func removeCategory(parent: CategoryResult.ID, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let industryCategoryResult = await modelController.industryCategoryResult(for: parent) else {
            return
        }
        
        // Find the cached records for the given category
        do {
            // Attempt to delete the cached record from CloudCache
            if let cachedRecord = try await cacheManager.cloudCacheService.fetchGroupedUserCachedRecords(for: "Category").first(where: { $0.title == industryCategoryResult.parentCategory }) {
                try await cacheManager.cloudCacheService.deleteUserCachedRecord(for: cachedRecord)
            }
            
            // Refresh the cache after deletion
            await cacheManager.refreshCachedCategories()
            try await cacheManager.refreshCache()
        } catch {
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Add Taste
    func addTaste(parent: CategoryResult.ID, rating:Double, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let tasteCategoryResult = await modelController.tasteCategoryResult(for: parent), !cacheManager.cachedTastes(contains: tasteCategoryResult.parentCategory) else {
            return
        }
        
        do {
            // Fetch the section related to the taste using assistiveHostDelegate
            let section = await modelController.assistiveHostDelegate.section(for: tasteCategoryResult.parentCategory).rawValue
            
            // Create a new UserCachedRecord for the taste
            let userRecord = UserCachedRecord(
                id:UUID(),
                recordId: UUID().uuidString,
                group: "Taste",
                identity: tasteCategoryResult.parentCategory,
                title: tasteCategoryResult.parentCategory,
                icons: "",
                list: section,
                section: section,
                rating: rating
            )
            
            // Save the record to the cache and CloudKit
            _ = try await cacheManager.cloudCacheService.storeUserCachedRecord(recordId: userRecord.recordId,
                group: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title,
                icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section,
                rating: userRecord.rating
            )
            
            // Refresh the cached tastes after adding the new record
            await cacheManager.refreshCachedTastes()
            try await cacheManager.refreshCache()
        } catch {
            // Track the error in analytics
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    /// Batch add multiple taste categories by their `CategoryResult.ID`s.
    /// - Parameters:
    ///   - parents: A list of `CategoryResult.ID` values to add.
    ///   - rating: The rating to assign to each added taste.
    ///   - cacheManager: Cache manager used to persist and refresh cached data.
    ///   - modelController: Model controller for analytics and lookups.
    public func addTastes(
        parents: [CategoryResult.ID],
        rating: Double,
        cacheManager: CacheManager,
        modelController: ModelController
    ) async {
        let uniqueParents = Array(Set(parents))
        guard !uniqueParents.isEmpty else { return }

        for parent in uniqueParents {
            await addTaste(
                parent: parent,
                rating: rating,
                cacheManager: cacheManager,
                modelController: modelController
            )
        }

        await cacheManager.refreshCachedTastes()
        do {
            try await cacheManager.refreshCache()
        } catch {
            await modelController.analyticsManager.trackError(
                error: error,
                additionalInfo: ["context": "SearchSavedViewModel.addTastes.refreshCache"]
            )
        }
    }
    
    // Remove Taste
    func removeTaste(parent: CategoryResult.ID, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let tasteCategoryResult = await modelController.cachedTasteResult(for: parent) else {
            return
        }

        do {
            // Fetch the cached record for the given taste
            if let cachedRecord = try await cacheManager.cloudCacheService.fetchGroupedUserCachedRecords(for: "Taste").first(where: { $0.title == tasteCategoryResult.parentCategory }) {
                // Delete the cached record
                try await cacheManager.cloudCacheService.deleteUserCachedRecord(for: cachedRecord)
            }
            // Refresh the cached tastes after deletion
            await cacheManager.refreshCachedTastes()
            try await cacheManager.refreshCache()
        } catch {
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Remove Cached Results
    func removeCachedResults(group: String, identity: String, cacheManager: CacheManager, modelController: ModelController) async {
        do {
            // Fetch cached records for the given group and identity
            let cachedRecords = try await cacheManager.cloudCacheService.fetchGroupedUserCachedRecords(for: group)
            let matchingRecords = cachedRecords.filter { $0.identity == identity }
            
            // Delete matching cached records sequentially to avoid sending non-Sendable values into concurrent closures
            var deletionErrors: [Error] = []
            for record in matchingRecords {
                do {
                    try await cacheManager.cloudCacheService.deleteUserCachedRecord(for: record)
                } catch {
                    deletionErrors.append(error)
                }
            }

            // Report any errors back on the main actor after deletions
            for err in deletionErrors {
                await modelController.analyticsManager.trackError(error: err, additionalInfo: nil)
            }
            
            // Refresh the cache after deletion
            switch group {
            case "Category":
                await cacheManager.refreshCachedCategories()
            case "Taste":
                await cacheManager.refreshCachedTastes()
            case "Place":
                await cacheManager.refreshCachedPlaces()
            case "Location":
                await cacheManager.refreshCachedLocations()
            default:
                break
            }
        } catch {
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    // Remove Cached Results (Batched)
    /// Removes multiple cached results for a given group and a list of identities.
    /// Performs deletions concurrently and refreshes the appropriate caches once at the end.
    /// - Parameters:
    ///   - group: The cache group (e.g., "Category", "Taste", "Place", "Location").
    ///   - identities: An array of identity strings to remove.
    ///   - cacheManager: Cache manager used to fetch and delete cached records.
    ///   - modelController: Model controller for analytics and error tracking.
    func removeCachedResults(
        group: String,
        identities: [String],
        cacheManager: CacheManager,
        modelController: ModelController
    ) async {
        guard !identities.isEmpty else { return }

        do {
            // Fetch cached records for the given group once
            let cachedRecords = try await cacheManager.cloudCacheService.fetchGroupedUserCachedRecords(for: group)
            let identitySet = Set(identities)
            let matchingRecords = cachedRecords.filter { identitySet.contains($0.identity) }

            // Delete matching cached records sequentially to avoid sending non-Sendable values into concurrent closures
            var deletionErrors: [Error] = []
            for record in matchingRecords {
                do {
                    try await cacheManager.cloudCacheService.deleteUserCachedRecord(for: record)
                } catch {
                    deletionErrors.append(error)
                }
            }

            for err in deletionErrors {
                await modelController.analyticsManager.trackError(error: err, additionalInfo: ["context": "removeCachedResults(batched)"])
            }

            // Refresh the cache once after all deletions
            switch group {
            case "Category":
                await cacheManager.refreshCachedCategories()
            case "Taste":
                await cacheManager.refreshCachedTastes()
            case "Place":
                await cacheManager.refreshCachedPlaces()
            case "Location":
                await cacheManager.refreshCachedLocations()
            default:
                break
            }

            // Optionally refresh the aggregate cache if needed
            do { try await cacheManager.refreshCache() } catch {
                await modelController.analyticsManager.trackError(error: error, additionalInfo: ["context": "removeCachedResults(batched).refreshCache"]) }
        } catch {
            await modelController.analyticsManager.trackError(error: error, additionalInfo: ["context": "removeCachedResults(batched).fetch"]) }
    }
    
    // Remove Saved Item
    func removeSelectedItem(selectedSavedResult: String, cacheManager:CacheManager, modelController:ModelController) async throws {
        
        if let selectedTasteItem = await modelController.cachedTasteResult(for: selectedSavedResult) {
            await removeCachedResults(group: "Taste", identity: selectedTasteItem.parentCategory, cacheManager: cacheManager, modelController: modelController)
        } else if let selectedCategoryItem = await modelController.cachedIndustryResult(for: selectedSavedResult) {
            await removeCachedResults(group: "Category", identity: selectedCategoryItem.parentCategory, cacheManager: cacheManager, modelController: modelController)
        } else if let selectedPlaceItem = await modelController.cachedPlaceResult(for: selectedSavedResult) {
            if let fsqID = selectedPlaceItem.categoricalChatResults.first?.placeResponse?.fsqID {
                await removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController: modelController)
                // Attempt to delete recommendation data if the underlying service supports it without enforcing protocol requirements
                if let concreteService = cacheManager.cloudCacheService as? AnyObject, concreteService.responds?(to: Selector(("deleteRecommendationDataWithFor:"))) == true {
                    // Use Objective-C selector check to avoid adding protocol requirements; call dynamically if bridged.
                    // If your CloudCacheService is pure Swift, consider exposing a separate helper in CacheManager instead.
                    _ = try? await (cacheManager.cloudCacheService as AnyObject).perform?(Selector(("deleteRecommendationDataWithFor:")), with: fsqID)
                }
            }
        }
    }
    
    // Change rating
    func changeRating(rating: Double, for editingResult:String, cacheManager:CacheManager, modelController:ModelController) async throws {
            try await cacheManager.cloudCacheService.updateUserCachedRecordRating(identity: editingResult, newRating: rating)

    }
}

