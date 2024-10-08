//
//  SearchSavedViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

public final class SearchSavedViewModel: ObservableObject {
    
    @Published var chatModel: ChatResultViewModel
    
    init(chatModel: ChatResultViewModel) {
        self.chatModel = chatModel
    }
    
    // Refresh Cache
    func refreshCache(cacheManager:CacheManager) async {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await cacheManager.refreshCache()
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Search functionality
    func search(caption: String, selectedDestinationChatResultID: UUID?, cacheManager:CacheManager) async {
        do {
            try await chatModel.didSearch(caption: caption, selectedDestinationChatResultID: selectedDestinationChatResultID, intent: .Location, cacheManager: cacheManager)
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Add Location
    
    func addLocation(parent:LocationResult,location:CLLocation, cacheManager:CacheManager) async throws {
        var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: cacheManager.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:PersonalizedSearchSection.location.rawValue, rating: 1)
        let record = try await cacheManager.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, icons: userRecord.icons, list:userRecord.list, section:userRecord.section, rating:userRecord.rating)
        userRecord.setRecordId(to:record)
        await refreshCache(cacheManager: cacheManager)
    }
    
    // Add Category
    func addCategory(parent: CategoryResult, cacheManager:CacheManager) async {
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
            await refreshCache(cacheManager: cacheManager)
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Remove Category
    func removeCategory(parent: CategoryResult, cacheManager:CacheManager) async {
        if let cachedResults = cacheManager.cachedResults(for: "Category", identity: parent.parentCategory) {
            for result in cachedResults {
                do {
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
            await refreshCache(cacheManager: cacheManager)
        }
    }
    
    // Add Taste
    func addTaste(parent: CategoryResult, cacheManager:CacheManager) async {
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
            await refreshCache(cacheManager: cacheManager)
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Remove Taste
    func removeTaste(parent: CategoryResult, cacheManager:CacheManager) async {
        if let cachedResults = cacheManager.cachedResults(for: "Taste", identity: parent.parentCategory) {
            for result in cachedResults {
                do {
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
            await refreshCache(cacheManager: cacheManager)
        }
    }
    
    // Remove Cached Results
    func removeCachedResults(group: String, identity: String, cacheManager:CacheManager) async {
        if let cachedResults = cacheManager.cachedResults(for: group, identity: identity) {
            await withTaskGroup(of: Void.self) { [weak self] group in
                guard let strongSelf = self else { return }
                for result in cachedResults {
                    group.addTask {
                        do {
                            try await cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                        } catch {
                            strongSelf.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                }
            }
            await refreshCache(cacheManager: cacheManager)
        }
    }
    
    // Remove Saved Item
    func removeSelectedItem(selectedSavedResult: UUID?, cacheManager:CacheManager) async throws {
        guard let selectedSavedResult = selectedSavedResult else { return }
        
        if let selectedTasteItem = chatModel.modelController.cachedTasteResult(for: selectedSavedResult, cacheManager: cacheManager) {
            await removeCachedResults(group: "Taste", identity: selectedTasteItem.parentCategory, cacheManager: cacheManager)
        } else if let selectedCategoryItem = chatModel.modelController.cachedCategoricalResult(for: selectedSavedResult, cacheManager: cacheManager) {
            await removeCachedResults(group: "Category", identity: selectedCategoryItem.parentCategory, cacheManager: cacheManager)
        } else if let selectedPlaceItem = chatModel.modelController.cachedPlaceResult(for: selectedSavedResult, cacheManager: cacheManager) {
            if let fsqID = selectedPlaceItem.categoricalChatResults.first?.placeResponse?.fsqID {
                await removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager)
            }
        }
    }
    
    // Change rating
    func changeRating(rating: Int, for editingResult:String, cacheManager:CacheManager) async throws {
        try await cacheManager.cloudCache.updateUserCachedRecordRating(recordId: editingResult, newRating: rating)
        await refreshCache(cacheManager: cacheManager)
    }
}
