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
    func refreshCache() async {
        do {
            try await chatModel.modelController.cacheManager.refreshCache()
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Search functionality
    func search(caption: String, selectedDestinationChatResultID: UUID?) async {
        do {
            try await chatModel.didSearch(caption: caption, selectedDestinationChatResultID: selectedDestinationChatResultID, intent: .Location)
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Add Location
    
    func addLocation(parent:LocationResult,location:CLLocation) async throws {
        var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.modelController.cacheManager.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:PersonalizedSearchSection.location.rawValue)
        let record = try await chatModel.modelController.cacheManager.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, icons: userRecord.icons, list:userRecord.list, section:userRecord.section)
        userRecord.setRecordId(to:record)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await chatModel.modelController.cacheManager.refreshCache()
    }
    
    // Add Category
    func addCategory(parent: CategoryResult) async {
        do {
            var userRecord = UserCachedRecord(
                recordId: "",
                group: "Category",
                identity: parent.parentCategory,
                title: parent.parentCategory,
                icons: "",
                list: parent.list,
                section: parent.section.rawValue
            )
            let record = try await chatModel.modelController.cacheManager.cloudCache.storeUserCachedRecord(
                for: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title, icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section
            )
            userRecord.setRecordId(to: record)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            await refreshCache()
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Remove Category
    func removeCategory(parent: CategoryResult) async {
        if let cachedResults = chatModel.modelController.cacheManager.cachedResults(for: "Category", identity: parent.parentCategory) {
            for result in cachedResults {
                do {
                    try await chatModel.modelController.cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
            await refreshCache()
        }
    }
    
    // Add Taste
    func addTaste(parent: CategoryResult) async {
        do {
            var userRecord = UserCachedRecord(
                recordId: "",
                group: "Taste",
                identity: parent.parentCategory,
                title: parent.parentCategory,
                icons: "",
                list: parent.list,
                section: parent.section.rawValue
            )
            let record = try await chatModel.modelController.cacheManager.cloudCache.storeUserCachedRecord(
                for: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title, icons: userRecord.icons,
                list: userRecord.list,
                section: userRecord.section
            )
            userRecord.setRecordId(to: record)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            await refreshCache()
        } catch {
            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Remove Taste
    func removeTaste(parent: CategoryResult) async {
        if let cachedResults = chatModel.modelController.cacheManager.cachedResults(for: "Taste", identity: parent.parentCategory) {
            for result in cachedResults {
                do {
                    try await chatModel.modelController.cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
            await refreshCache()
        }
    }
    
    // Remove Cached Results
    func removeCachedResults(group: String, identity: String) async {
        if let cachedResults = chatModel.modelController.cacheManager.cachedResults(for: group, identity: identity) {
            await withTaskGroup(of: Void.self) { [weak self] group in
                guard let strongSelf = self else { return }
                for result in cachedResults {
                    group.addTask {
                        do {
                            try await strongSelf.chatModel.modelController.cacheManager.cloudCache.deleteUserCachedRecord(for: result)
                            await strongSelf.refreshCache()
                        } catch {
                            strongSelf.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                }
            }
        }
    }
    
    // Remove Saved Item
    func removeSelectedItem(selectedSavedResult: UUID?) async throws {
        guard let selectedSavedResult = selectedSavedResult else { return }
        
        if let selectedTasteItem = chatModel.modelController.cachedTasteResult(for: selectedSavedResult) {
            await removeCachedResults(group: "Taste", identity: selectedTasteItem.parentCategory)
        } else if let selectedCategoryItem = chatModel.modelController.cachedCategoricalResult(for: selectedSavedResult) {
            await removeCachedResults(group: "Category", identity: selectedCategoryItem.parentCategory)
        } else if let selectedPlaceItem = chatModel.modelController.cachedPlaceResult(for: selectedSavedResult) {
            if let fsqID = selectedPlaceItem.categoricalChatResults.first?.placeResponse?.fsqID {
                await removeCachedResults(group: "Place", identity: fsqID)
            }
        }
    }
}
