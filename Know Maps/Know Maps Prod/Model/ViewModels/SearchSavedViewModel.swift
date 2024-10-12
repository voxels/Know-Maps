//
//  SearchSavedViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

@Observable
public final class SearchSavedViewModel : Sendable {
    
    public var filters: [String:Any] = [:]
    public var editingRecommendationWeightResult: CategoryResult?
    
    // Search functionality
    func search(caption: String, selectedDestinationChatResultID: UUID?, intent:AssistiveChatHostService.Intent, filters:[String:Any], chatModel:ChatResultViewModel, cacheManager:CacheManager, modelController:ModelController) async {
        do {
            try await chatModel.didSearch(caption: caption, selectedDestinationChatResultID: selectedDestinationChatResultID, intent:intent, filters: filters, cacheManager: cacheManager, modelController:modelController)
        } catch {
            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // MARK: - Helper Functions
    
    func updateRating(for result: CategoryResult, rating: Double,  cacheManager:CacheManager, modelController:ModelController) {
        Task(priority: .userInitiated) {
            do {
                try await changeRating(rating: rating, for: result.identity, cacheManager: cacheManager, modelController: modelController)
                await cacheManager.refreshCachedTastes()
                await cacheManager.refreshCachedCategories()
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
            editingRecommendationWeightResult = nil
        }
    }
    
    // Add Location
    func addLocation(parent: LocationResult, location: CLLocation, cacheManager: CacheManager, modelController: ModelController) async throws {
        do {
            // Create a new UserCachedRecord for the location
            let userRecord = UserCachedRecord(
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
            _ = try await cacheManager.cloudCache.storeUserCachedRecord(recordId: userRecord.recordId,
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
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            throw error
        }
    }
    
    // Add Category
    func addCategory(parent: CategoryResult.ID, rating:Double, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let industryCategoryResult = modelController.industryCategoryResult(for: parent), !cacheManager.cachedCategories(contains: industryCategoryResult.parentCategory) else {
            return
        }

        do {
            // Create a new UserCachedRecord for the category
            let userRecord = UserCachedRecord(
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
            _ = try await cacheManager.cloudCache.storeUserCachedRecord(recordId: userRecord.recordId,
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
        } catch {
            // Log any errors with the analytics manager
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Remove Category
    func removeCategory(parent: CategoryResult.ID, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let industryCategoryResult = modelController.industryCategoryResult(for: parent) else {
            return
        }
        
        // Find the cached records for the given category
        do {
            // Attempt to delete the cached record from CloudCache
            if let cachedRecord = try await cacheManager.cloudCache.fetchGroupedUserCachedRecords(for: "Category").first(where: { $0.title == industryCategoryResult.parentCategory }) {
                try await cacheManager.cloudCache.deleteUserCachedRecord(for: cachedRecord)
            }
            
            // Refresh the cache after deletion
            await cacheManager.refreshCachedCategories()
        } catch {
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Add Taste
    func addTaste(parent: CategoryResult.ID, rating:Double, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let tasteCategoryResult = modelController.tasteCategoryResult(for: parent), !cacheManager.cachedTastes(contains: tasteCategoryResult.parentCategory) else {
            return
        }
        
        do {
            // Fetch the section related to the taste using assistiveHostDelegate
            let section = modelController.assistiveHostDelegate.section(for: tasteCategoryResult.parentCategory).rawValue
            
            // Create a new UserCachedRecord for the taste
            let userRecord = UserCachedRecord(
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
            _ = try await cacheManager.cloudCache.storeUserCachedRecord(recordId: userRecord.recordId,
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
        } catch {
            // Track the error in analytics
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }

    // Remove Taste
    func removeTaste(parent: CategoryResult.ID, cacheManager: CacheManager, modelController: ModelController) async {
        
        guard let tasteCategoryResult = modelController.cachedTasteResult(for: parent, cacheManager: cacheManager) else {
            return
        }

        do {
            // Fetch the cached record for the given taste
            if let cachedRecord = try await cacheManager.cloudCache.fetchGroupedUserCachedRecords(for: "Taste").first(where: { $0.title == tasteCategoryResult.parentCategory }) {
                // Delete the cached record
                try await cacheManager.cloudCache.deleteUserCachedRecord(for: cachedRecord)
            }
            // Refresh the cached tastes after deletion
            await cacheManager.refreshCachedTastes()
        } catch {
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Remove Cached Results
    func removeCachedResults(group: String, identity: String, cacheManager: CacheManager, modelController: ModelController) async {
        do {
            // Fetch cached records for the given group and identity
            let cachedRecords = try await cacheManager.cloudCache.fetchGroupedUserCachedRecords(for: group)
            let matchingRecords = cachedRecords.filter { $0.identity == identity }
            
            // Delete matching cached records concurrently
            await withTaskGroup(of: Void.self) { group in
                for record in matchingRecords {
                    group.addTask {
                        do {
                            try await cacheManager.cloudCache.deleteUserCachedRecord(for: record)
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
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
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    // Remove Saved Item
    func removeSelectedItem(selectedSavedResult: UUID?, cacheManager:CacheManager, modelController:ModelController) async throws {
        guard let selectedSavedResult = selectedSavedResult else { return }
        
        if let selectedTasteItem = modelController.cachedTasteResult(for: selectedSavedResult, cacheManager: cacheManager) {
            await removeCachedResults(group: "Taste", identity: selectedTasteItem.parentCategory, cacheManager: cacheManager, modelController: modelController)
        } else if let selectedCategoryItem = modelController.cachedCategoricalResult(for: selectedSavedResult, cacheManager: cacheManager) {
            await removeCachedResults(group: "Category", identity: selectedCategoryItem.parentCategory, cacheManager: cacheManager, modelController: modelController)
        } else if let selectedPlaceItem = modelController.cachedPlaceResult(for: selectedSavedResult, cacheManager: cacheManager) {
            if let fsqID = selectedPlaceItem.categoricalChatResults.first?.placeResponse?.fsqID {
                await removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController: modelController)
                _ = try await cacheManager.cloudCache.deleteRecommendationData(for: fsqID)
            }
        }
    }
    
    // Change rating
    func changeRating(rating: Double, for editingResult:String, cacheManager:CacheManager, modelController:ModelController) async throws {
        try await cacheManager.cloudCache.updateUserCachedRecordRating(identity: editingResult, newRating: rating)
    }
}
