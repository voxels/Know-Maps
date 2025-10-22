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
    
    public static let shared = SearchSavedViewModel()
    
    public var filters: [String:Any] {
        get {
            retrieveFiltersFromUserDefaults()
        }
        
        set{
            saveFiltersToUserDefaults(filters: newValue)
        }
    }
    public var editingRecommendationWeightResult: CategoryResult?
    
    
    func saveFiltersToUserDefaults(filters: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: filters, options: [])
            UserDefaults.standard.set(data, forKey: "savedFilters")
        } catch {
            print("Error saving filters: \(error.localizedDescription)")
        }
    }
    
    func retrieveFiltersFromUserDefaults() -> [String: Any] {
        if let data = UserDefaults.standard.data(forKey: "savedFilters") {
            do {
                if let filters = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    return filters
                }
            } catch {
                print("Error retrieving filters: \(error.localizedDescription)")
            }
        }
        return [:]
    }
    
    // Search functionality
    func search(caption: String, selectedDestinationChatResult: LocationResult, intent:AssistiveChatHostService.Intent, filters:[String:Any], chatModel:ChatResultViewModel, cacheManager:CacheManager, modelController:ModelController) async {
        do {
            try await chatModel.didSearch(caption: caption, selectedDestinationChatResult: selectedDestinationChatResult , intent:intent, filters: filters, modelController:modelController)
        } catch {
            await modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
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
            
            // Delete matching cached records concurrently
            await withTaskGroup(of: Void.self) { group in
                for record in matchingRecords {
                    group.addTask {
                        do {
                            try await cacheManager.cloudCacheService.deleteUserCachedRecord(for: record)
                        } catch {
                            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
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
            await modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
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
                _ = try await cacheManager.cloudCacheService.deleteRecommendationData(for: fsqID)
            }
        }
    }
    
    // Change rating
    func changeRating(rating: Double, for editingResult:String, cacheManager:CacheManager, modelController:ModelController) async throws {
            try await cacheManager.cloudCacheService.updateUserCachedRecordRating(identity: editingResult, newRating: rating)

    }
}
