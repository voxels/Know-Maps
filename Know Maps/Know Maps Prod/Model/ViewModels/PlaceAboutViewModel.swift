//
//  PlaceAboutViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import SwiftUI
import CoreLocation
import CallKit

class PlaceAboutViewModel: ObservableObject {
    @Published var chatModel: ChatResultViewModel
    @Published var isSaved: Bool = false
    @Published var isPresentingShareSheet: Bool = false
    
    init(chatModel: ChatResultViewModel) {
        self.chatModel = chatModel
    }

    func toggleSavePlace(resultId:ChatResult.ID?) async {
        guard let resultId = resultId, let placeResult = chatModel.modelController.placeChatResult(for: resultId), let placeResponse = placeResult.placeResponse else {
            return
        }
        
        isSaved = chatModel.modelController.cacheManager.cachedPlaces(contains: placeResult.title)
        
        if isSaved {
            // Delete from cache
            if let cachedPlaceResults = chatModel.modelController.cacheManager.cachedResults(for: "Place", identity: placeResponse.fsqID), let cachedPlaceResult = cachedPlaceResults.first {
                do {
                    try await chatModel.modelController.cacheManager.cloudCache.deleteUserCachedRecord(for: cachedPlaceResult)
                    try await chatModel.modelController.cacheManager.refreshCache()
                } catch {
                    print(error)
                }
            }
        } else {
            // Save to cache
            do {
                var userRecord = UserCachedRecord(recordId: "", group: "Place", identity: placeResponse.fsqID, title: placeResult.title, icons: "", list: placeResult.list, section: placeResult.section.rawValue)
                let record = try await chatModel.modelController.cacheManager.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, icons: userRecord.icons, list: userRecord.list, section: userRecord.section)
                userRecord.setRecordId(to: record)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await chatModel.modelController.cacheManager.refreshCache()
            } catch {
                print(error)
            }
        }
        
        isSaved.toggle()
    }
    
    func getCallURL(tel: String) -> URL? {
        return URL(string: "tel://\(tel)")
    }
    
    func getWebsiteURL(website: String) -> URL? {
        return URL(string: website)
    }
}
