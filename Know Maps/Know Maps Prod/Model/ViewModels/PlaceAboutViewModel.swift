//
//  PlaceAboutViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import SwiftUI
import CoreLocation
import CallKit

class PlaceAboutViewModel {
    
    func toggleSavePlace(resultId:ChatResult.ID?, cacheManager:CacheManager, modelController:ModelController) async {
        guard let resultId = resultId, let placeResult = modelController.placeChatResult(for: resultId), let placeResponse = placeResult.placeResponse else {
            return
        }
        let saved = cacheManager.cachedPlaces(contains: placeResult.title)
        
        if saved {
            // Delete from cache
            if let cachedPlaceResults = cacheManager.cachedResults(for: "Place", identity: placeResponse.fsqID), let cachedPlaceResult = cachedPlaceResults.first {
                do {
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: cachedPlaceResult)
                    try await cacheManager.refreshCache()
                } catch {
                    print(error)
                }
            }
        } else {
            // Save to cache
            do {
                var userRecord = UserCachedRecord(recordId: "", group: "Place", identity: placeResponse.fsqID, title: placeResult.title, icons: "", list: placeResult.list, section: placeResult.section.rawValue, rating:1)
                let record = try await cacheManager.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, icons: userRecord.icons, list: userRecord.list, section: userRecord.section, rating:userRecord.rating)
                userRecord.setRecordId(to: record)
                try await cacheManager.refreshCache()
            } catch {
                print(error)
            }
        }
    }
    
    func getCallURL(tel: String) -> URL? {
        return URL(string: "tel://\(tel)")
    }
    
    func getWebsiteURL(website: String) -> URL? {
        return URL(string: website)
    }
}
