//
//  SearchSavedViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

public final class SearchSavedViewModel: ObservableObject {
    // Refresh Cache
    func refreshCache(cacheManager:CacheManager, modelController:ModelController) async {
        do {
            try await Task.sleep(for:.seconds(1))
            try await cacheManager.refreshCache()
        } catch {
            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Search functionality
    func search(caption: String, selectedDestinationChatResultID: UUID?, chatModel:ChatResultViewModel, cacheManager:CacheManager, modelController:ModelController) async {
        do {
            try await chatModel.didSearch(caption: caption, selectedDestinationChatResultID: selectedDestinationChatResultID, intent: .Location, cacheManager: cacheManager, modelController:modelController)
        } catch {
            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Add Location
    
    func addLocation(parent:LocationResult,location:CLLocation, cacheManager:CacheManager, modelController:ModelController) async throws {
        var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: cacheManager.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:PersonalizedSearchSection.location.rawValue, rating: 1)
        let record = try await cacheManager.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, icons: userRecord.icons, list:userRecord.list, section:userRecord.section, rating:userRecord.rating)
        userRecord.setRecordId(to:record)
        await refreshCache(cacheManager: cacheManager, modelController: modelController)
    }
    
    // Add Category
    func addCategory(parent: CategoryResult, cacheManager:CacheManager, modelController:ModelController) async {
        do {
            var userRecord = UserCachedRecord(
                recordId: "",
                group: "Category",
                identity: parent.parentCategory,
                title: parent.parentCategory,
                icons: "",
                list: parent.list,
                section: parent.section.rawValue,
                rating: 1
            )
            let record = try await cacheManager.cloudCache.storeUserCachedRecord(
                for: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title, icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section,
                rating:userRecord.rating
            )
            userRecord.setRecordId(to: record)
            await refreshCache(cacheManager: cacheManager, modelController: modelController)
        } catch {
            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Remove Category
    func removeCategory(parent: CategoryResult, cacheManager:CacheManager, modelController:ModelController) async {
        if let cachedResults = cacheManager.cachedResults(for: "Category", identity: parent.parentCategory) {
            for result in cachedResults {
                do {
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
            await refreshCache(cacheManager: cacheManager, modelController: modelController)
        }
    }
    
    // Add Taste
    func addTaste(parent: CategoryResult, cacheManager:CacheManager, modelController:ModelController) async {
        do {
            var userRecord = UserCachedRecord(
                recordId: "",
                group: "Taste",
                identity: parent.parentCategory,
                title: parent.parentCategory,
                icons: "",
                list: parent.list,
                section: parent.section.rawValue,
                rating: 1
            )
            let record = try await cacheManager.cloudCache.storeUserCachedRecord(
                for: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title, icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section,
                rating:userRecord.rating
            )
            userRecord.setRecordId(to: record)
            await refreshCache(cacheManager: cacheManager, modelController: modelController)
        } catch {
            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Remove Taste
    func removeTaste(parent: CategoryResult, cacheManager:CacheManager, modelController:ModelController) async {
        if let cachedResults = cacheManager.cachedResults(for: "Taste", identity: parent.parentCategory) {
            for result in cachedResults {
                do {
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
            await refreshCache(cacheManager: cacheManager, modelController:modelController)
        }
    }
    
    // Remove Cached Results
    func removeCachedResults(group: String, identity: String, cacheManager:CacheManager, modelController:ModelController) async {
        if let cachedResults = cacheManager.cachedResults(for: group, identity: identity) {
            await withTaskGroup(of: Void.self) { group in
                for result in cachedResults {
                    group.addTask {
                        do {
                            try await cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                }
            }
            await refreshCache(cacheManager: cacheManager, modelController: modelController)
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
                _ = try await cacheManager.cloudCache.deleteRecomendationData(for: fsqID)
            }
        }
    }
    
    // Change rating
    func changeRating(rating: Double, for editingResult:String, cacheManager:CacheManager, modelController:ModelController) async throws {
        try await cacheManager.cloudCache.updateUserCachedRecordRating(recordId: editingResult, newRating: rating)
        await refreshCache(cacheManager: cacheManager, modelController: modelController)
    }
}
