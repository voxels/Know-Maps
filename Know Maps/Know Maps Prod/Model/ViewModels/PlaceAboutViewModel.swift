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
        await cacheManager.refreshCachedResults()
    }
    
    // Add Taste
    func addTaste(title: String, cacheManager: CacheManager, modelController: ModelController) async {
        do {
            // Fetch the section related to the taste using assistiveHostDelegate
            let section = modelController.assistiveHostDelegate.section(for: title).rawValue
            
            // Create a new UserCachedRecord for the taste
            let userRecord = UserCachedRecord(
                recordId: UUID().uuidString,
                group: "Taste",
                identity: title,
                title: title,
                icons: "",
                list: section,
                section: section,
                rating: 1
            )
            
            // Save the record to the cache and CloudKit
            let _ = try await cacheManager.cloudCache.storeUserCachedRecord(recordId: userRecord.recordId,
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
    func removeTaste(parent: CategoryResult, cacheManager: CacheManager, modelController: ModelController) async {
        // Check if the taste exists in the cache
        if cacheManager.cachedTastes(contains: parent.parentCategory) {
            do {
                // Fetch the cached record for the given taste
                if let cachedRecord = try await cacheManager.cloudCache.fetchGroupedUserCachedRecords(for: "Taste").first(where: { $0.title == parent.parentCategory }) {
                    // Delete the cached record
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: cachedRecord)
                }
                // Refresh the cached tastes after deletion
                await cacheManager.refreshCachedTastes()
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
    }
    
    func toggleSavePlace(resultId: ChatResult.ID?, cacheManager: CacheManager, modelController: ModelController) async {
        guard let resultId = resultId,
              let placeResult = modelController.placeChatResult(for: resultId),
              let placeResponse = placeResult.placeResponse else {
            return
        }

        // Check if the place is already saved
        let saved = cacheManager.cachedPlaces(contains: placeResult.title)

        if saved {
            // Delete from cache
            do {
                // Fetch the cached place record
                if let cachedRecord = try await cacheManager.cloudCache.fetchGroupedUserCachedRecords(for: "Place")
                    .first(where: { $0.identity == placeResponse.fsqID }) {
                    
                    // Delete the record from CloudKit
                    try await cacheManager.cloudCache.deleteUserCachedRecord(for: cachedRecord)
                }
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        } else {
            // Save to cache
            do {
                // Create a new cached record for the place
                let userRecord = UserCachedRecord(
                    recordId: UUID().uuidString,
                    group: "Place",
                    identity: placeResponse.fsqID,
                    title: placeResult.title,
                    icons: "",
                    list: placeResult.list,
                    section: placeResult.section.rawValue,
                    rating: 1
                )
                
                if let placeDetailsResponse = placeResult.placeDetailsResponse {
                    // Save recommendation data if available
                    let identity = placeResponse.fsqID
                    let attributes = placeDetailsResponse.tastes ?? []
                    let reviews = placeDetailsResponse.tipsResponses?.compactMap { $0.text } ?? []
                    
                    var ratings = [String: Double]()
                    for attribute in attributes {
                        ratings[attribute] = 1.5
                    }
                    
                    let recommendation = RecommendationData(
                        recordId: UUID().uuidString,
                        identity: identity,
                        attributes: attributes,
                        reviews: reviews,
                        attributeRatings: ratings
                    )
                    
                    let _ = try await cacheManager.cloudCache.storeRecommendationData(
                        for: recommendation.identity,
                        attributes: recommendation.attributes,
                        reviews: recommendation.reviews
                    )
                    
                    // Save the user record with recommendation data
                    let _ = try await cacheManager.cloudCache.storeUserCachedRecord(recordId:UUID().uuidString,
                        group: userRecord.group,
                        identity: userRecord.identity,
                        title: userRecord.title,
                        icons: userRecord.icons,
                        list: userRecord.list,
                        section: userRecord.section,
                        rating: userRecord.rating
                    )
                } else {
                    // Save the user record without recommendation data
                    let _ = try await cacheManager.cloudCache.storeUserCachedRecord(recordId:UUID().uuidString,
                        group: userRecord.group,
                        identity: userRecord.identity,
                        title: userRecord.title,
                        icons: userRecord.icons,
                        list: userRecord.list,
                        section: userRecord.section,
                        rating: userRecord.rating
                    )
                }
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
        // Refresh the cached places after deletion
        await cacheManager.refreshCachedPlaces()
    }
    
    func getCallURL(tel: String) -> URL? {
        return URL(string: "tel://\(tel)")
    }
    
    func getWebsiteURL(website: String) -> URL? {
        return URL(string: website)
    }
}
