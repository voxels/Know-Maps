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
    
    // Refresh Cache
    func refreshCache(cacheManager:CacheManager, modelController:ModelController) async {
        do {
            try await Task.sleep(for:.seconds(1))
            try await cacheManager.refreshCache()
        } catch {
            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
        }
    }
    
    // Add Taste
    func addTaste(title: String, cacheManager:CacheManager, modelController:ModelController) async {
        do {
            let section = modelController.assistiveHostDelegate.section(for:title).rawValue
            var userRecord = UserCachedRecord(
                recordId: "",
                group: "Taste",
                identity: title,
                title: title,
                icons: "",
                list: section,
                section: section,
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
                let ckRecord = cacheManager.cloudCache.userCachedCKRecord(for: userRecord)
                if let placeDetailsResponse = placeResult.placeDetailsResponse {
                    let identity = placeResponse.fsqID
                    let attributes = placeDetailsResponse.tastes ?? []
                    let reviews = placeDetailsResponse.tipsResponses?.compactMap({ tipsResponse in
                        return tipsResponse.text
                    }) ?? []
                    
                    var ratings = [String:Double]()
                    for attribute in attributes {
                        ratings[attribute] = 1.5
                    }
                    
                    var recommendation = RecommendationData(recordId: "", identity: identity, attributes: attributes, reviews: reviews, attributeRatings: ratings)
                    let recRecord = try await cacheManager.cloudCache.storeRecommendationData(for: recommendation.identity, attributes: recommendation.attributes, reviews: recommendation.reviews, userCachedCKRecord: ckRecord)
                    recommendation.setRecordId(to: recRecord)
                } else {
                    let record = try await cacheManager.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, icons: userRecord.icons, list: userRecord.list, section: userRecord.section, rating:userRecord.rating)
                    userRecord.setRecordId(to: record)
                }
                
                try await cacheManager.refreshCache()
            } catch {
                print(error)
            }
        }
        await refreshCache(cacheManager: cacheManager, modelController:modelController)

    }
    
    func getCallURL(tel: String) -> URL? {
        return URL(string: "tel://\(tel)")
    }
    
    func getWebsiteURL(website: String) -> URL? {
        return URL(string: website)
    }
}
