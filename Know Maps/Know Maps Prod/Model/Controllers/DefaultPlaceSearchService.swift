//
//  PlaceSearchService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

@Observable
public final class DefaultPlaceSearchService: PlaceSearchService {
    
    public let assistiveHostDelegate: AssistiveChatHost
    public let placeSearchSession: PlaceSearchSession
    public let personalizedSearchSession: PersonalizedSearchSession
    public let analyticsManager: AnalyticsService
    
    public var lastFetchedTastePage: Int = 0
    
    public init(
        assistiveHostDelegate: AssistiveChatHost,
        placeSearchSession: PlaceSearchSession,
        personalizedSearchSession: PersonalizedSearchSession,
        analyticsManager: AnalyticsService
    ) {
        self.assistiveHostDelegate = assistiveHostDelegate
        self.placeSearchSession = placeSearchSession
        self.personalizedSearchSession = personalizedSearchSession
        self.analyticsManager = analyticsManager
    }
    
    public func retrieveFsqUser(cacheManager:CacheManager) async throws {
        try await personalizedSearchSession.fetchManagedUserIdentity(cacheManager:cacheManager)
        try await personalizedSearchSession.fetchManagedUserAccessToken(cacheManager: cacheManager)
        
        if await personalizedSearchSession.fsqIdentity == nil {
            try await personalizedSearchSession.addFoursquareManagedUserIdentity(cacheManager: cacheManager)
        }
    }
    
    public func fetchDetails(for responses: [PlaceSearchResponse]) async throws -> [PlaceDetailsResponse] {
        return try await withThrowingTaskGroup(of: PlaceDetailsResponse.self) { [weak self] group in
            guard let self = self else { return [] }
            for response in responses {
                group.addTask {
                    let request = PlaceDetailsRequest(
                        fsqID: response.fsqID,
                        core: response.name.isEmpty,
                        description: true,
                        tel: true,
                        fax: false,
                        email: false,
                        website: true,
                        socialMedia: true,
                        verified: false,
                        hours: true,
                        hoursPopular: true,
                        rating: true,
                        stats: false,
                        popularity: true,
                        price: true,
                        menu: true,
                        tastes: true,
                        features: false
                    )
                    
                    var rawDetailsResponse: Any?
                    var tipsData: Any?
                    var photosData: Any?
                    
                    try await withThrowingTaskGroup(of: Void.self) { innerGroup in
                        // Fetch details
                        innerGroup.addTask { [weak self] in
                            rawDetailsResponse = try await self?.placeSearchSession.details(for: request)
                            self?.analyticsManager.track(event: "fetchDetails", properties: nil)
                        }
                        
                        // Fetch tips in parallel
                        innerGroup.addTask {
                            tipsData = try await self.placeSearchSession.tips(for: response.fsqID)
                        }
                        // Fetch photos in parallel
                        innerGroup.addTask {
                            photosData = try await self.placeSearchSession.photos(for: response.fsqID)
                        }
                        // Wait for all tasks to complete
                        try await innerGroup.waitForAll()
                    }
                    
                    let tipsResponses = try PlaceResponseFormatter.placeTipsResponses(with: tipsData!, for: response.fsqID)
                    let photoResponses = try PlaceResponseFormatter.placePhotoResponses(with: photosData!, for: response.fsqID)
                    
                    return try await PlaceResponseFormatter.placeDetailsResponse(
                        with: rawDetailsResponse!,
                        for: response,
                        placePhotosResponses: photoResponses,
                        placeTipsResponses: tipsResponses,
                        previousDetails: self.assistiveHostDelegate.queryIntentParameters.queryIntents.last?.placeDetailsResponses
                    )
                }
            }
            var allResponses = [PlaceDetailsResponse]()
            for try await response in group {
                allResponses.append(response)
            }
            return allResponses
        }
    }
    
    public func fetchRelatedPlaces(for fsqID: String, cacheManager:CacheManager) async throws -> [RecommendedPlaceSearchResponse] {
        let rawRelatedVenuesResponse = try await personalizedSearchSession.fetchRelatedVenues(for: fsqID, cacheManager: cacheManager)
        return try PlaceResponseFormatter.relatedPlaceSearchResponses(with: rawRelatedVenuesResponse)
    }
    
    // MARK: Autocomplete Methods
    
    public func autocompleteTastes(lastIntent: AssistiveChatHostIntent, currentTasteResults:[CategoryResult], cacheManager:CacheManager) async throws -> [CategoryResult] {
        let query = lastIntent.caption
        let rawResponse = try await personalizedSearchSession.autocompleteTastes(caption: query, parameters: lastIntent.queryParameters, cacheManager: cacheManager)
        let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: rawResponse)
        let results = tasteCategoryResults(with: tastes.map(\.text), page: 0, currentTasteResults: currentTasteResults)
        
        return results
    }
    
    public func refreshTastes(page: Int, currentTasteResults:[CategoryResult], cacheManager:CacheManager) async throws -> [CategoryResult] {
        let tastes = try await personalizedSearchSession.fetchTastes(page: page, cacheManager: cacheManager)
        let results = tasteCategoryResults(with: tastes, page: page, currentTasteResults: currentTasteResults)
        lastFetchedTastePage = page
        return results
    }
        
    private func tasteCategoryResults(with tastes: [String], page: Int, currentTasteResults: [CategoryResult]) -> [CategoryResult] {
        var results = currentTasteResults
        
        for index in 0..<tastes.count {
            let taste = tastes[index]
            let chatResult = ChatResult(index: index, identity: taste, title: taste, list:"Taste", icon: "", rating: 1, section:assistiveHostDelegate.section(for:taste), placeResponse: nil, recommendedPlaceResponse: nil)
            let categoryResult = CategoryResult(identity:taste, parentCategory: taste, list:"Taste", icon: chatResult.icon, rating: 1, section:chatResult.section, categoricalChatResults: [chatResult])
            results.append(categoryResult)
        }
        
        return results
    }
    
    // MARK: Detail Intent
    
    public func detailIntent(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws {
        if intent.selectedPlaceSearchDetails == nil {
            if let placeSearchResponse = intent.selectedPlaceSearchResponse {
                intent.selectedPlaceSearchDetails = try await fetchDetails(for: [placeSearchResponse]).first
                intent.placeDetailsResponses = [intent.selectedPlaceSearchDetails!]
                intent.relatedPlaceSearchResponses = try await fetchRelatedPlaces(for: placeSearchResponse.fsqID, cacheManager: cacheManager)
            }
        }
    }
        
    //MARK: - Request Building
    
    public func placeSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async ->PlaceSearchRequest {
        var query = intent.caption
        
        var ll:String? = nil
        var openNow:Bool? = nil
        var openAt:String? = nil
        var nearLocation:String? = nil
        var minPrice = 1
        var maxPrice = 4
        var radius = 50000
        var sort:String? = nil
        var limit:Int = 50
        var categories = ""
        
        if let revisedQuery = intent.queryParameters?["query"] as? String {
            query = revisedQuery
        }
        
        if let rawParameters = intent.queryParameters?["parameters"] as? NSDictionary {
            
            
            if let rawMinPrice = rawParameters["min_price"] as? Int, rawMinPrice > 1 {
                minPrice = rawMinPrice
            }
            
            if let rawMaxPrice = rawParameters["max_price"] as? Int, rawMaxPrice < 4 {
                maxPrice = rawMaxPrice
            }
            
            if let rawRadius = rawParameters["radius"] as? Int, rawRadius > 0 {
                radius = rawRadius
            }
            
            if let rawSort = rawParameters["sort"] as? String {
                sort = rawSort
            }
            
            
            if let rawCategories = rawParameters["categories"] as? [String] {
                for rawCategory in rawCategories {
                    categories.append(rawCategory)
                    if rawCategories.count > 1 {
                        categories.append(",")
                    }
                }
            }
            
            
            if let rawTips = rawParameters["tips"] as? [String] {
                for rawTip in rawTips {
                    if !query.contains(rawTip) {
                        query.append("\(rawTip) ")
                    }
                }
            }
            
            if let rawTastes = rawParameters["tastes"] as? [String] {
                for rawTaste in rawTastes {
                    if !query.contains(rawTaste) {
                        query.append("\(rawTaste) ")
                    }
                }
            }
            
            if let rawNear = rawParameters["near"] as? String {
                nearLocation = rawNear
            }
            
            if let rawOpenAt = rawParameters["open_at"] as? String, rawOpenAt.count > 0 {
                openAt = rawOpenAt
            }
            
            if let rawOpenNow = rawParameters["open_now"] as? Bool {
                openNow = rawOpenNow
            }
            
            if let rawLimit = rawParameters["limit"] as? Int {
                limit = rawLimit
            }
        }
        
        print("Created query for search request:\(query) near location:\(String(describing: nearLocation)) with selected chat result: \(String(describing: location))")
        if let l = location {
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
        }
        
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = PlaceSearchRequest(query:query, ll: ll, radius:radius, categories: categories, fields: nil, minPrice: minPrice, maxPrice: maxPrice, openAt: openAt, openNow: openNow, nearLocation: nearLocation, sort: sort, limit:limit)
        return request
    }
    
    public func recommendedPlaceSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async -> RecommendedPlaceSearchRequest
    {
        var query = intent.caption
        
        var ll:String? = nil
        var openNow:Bool? = nil
        var nearLocation:String? = nil
        var minPrice = 1
        var maxPrice = 4
        var radius = 20000
        var limit:Int = 50
        var categories = ""
        var section:PersonalizedSearchSection? = nil
        var tags = AssistiveChatHostTaggedWord()
        
        if let revisedQuery = intent.queryParameters?["query"] as? String {
            query = revisedQuery
        }
        
        if let rawParameters = intent.queryParameters?["parameters"] as? NSDictionary {
            
            
            if let rawMinPrice = rawParameters["min_price"] as? Int, rawMinPrice > 1 {
                minPrice = rawMinPrice
            }
            
            if let rawMaxPrice = rawParameters["max_price"] as? Int, rawMaxPrice < 4 {
                maxPrice = rawMaxPrice
            }
            
            if let rawRadius = rawParameters["radius"] as? Int, rawRadius > 0 {
                radius = rawRadius
            }
            
            
            if let rawCategories = rawParameters["categories"] as? [String] {
                for rawCategory in rawCategories {
                    categories.append(rawCategory)
                    if rawCategories.count > 1 {
                        categories.append(",")
                    }
                }
            } else {
                
            }
            
            if let rawTips = rawParameters["tips"] as? [String] {
                for rawTip in rawTips {
                    if !query.contains(rawTip) {
                        query.append("\(rawTip) ")
                    }
                }
            }
            
            if let rawTastes = rawParameters["tastes"] as? [String] {
                for rawTaste in rawTastes {
                    if !query.contains(rawTaste) {
                        query.append("\(rawTaste) ")
                    }
                }
            }
            
            if let rawNear = rawParameters["near"] as? String {
                nearLocation = rawNear
            }
            
            if let rawOpenNow = rawParameters["open_now"] as? Bool {
                openNow = rawOpenNow
            }
            
            if let rawLimit = rawParameters["limit"] as? Int {
                limit = rawLimit
            }
            
            if let rawTags = rawParameters["tags"] as? AssistiveChatHostTaggedWord {
                tags = rawTags
            }
            
            if let rawSection = rawParameters["section"] as? String {
                section = PersonalizedSearchSection(rawValue: rawSection) ?? .food
            }
        }
        
        print("Created query for search request:\(query) near location:\(String(describing: nearLocation)) with selected chat result: \(String(describing: location))")
        if let l = location {
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
        }
        
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = RecommendedPlaceSearchRequest(query: query, ll: ll, radius: radius, categories: categories, minPrice:minPrice, maxPrice:maxPrice, openNow: openNow, nearLocation: nearLocation, limit: limit, section:section ?? .topPicks, tags:tags)
        
        return request
    }
}
