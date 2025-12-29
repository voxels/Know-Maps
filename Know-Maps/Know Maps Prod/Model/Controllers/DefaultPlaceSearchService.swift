//
//  PlaceSearchService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

import Foundation
import CoreLocation

@Observable
public final class DefaultPlaceSearchService: @preconcurrency PlaceSearchService {
    public let assistiveHostDelegate: AssistiveChatHost
    public let placeSearchSession: PlaceSearchSessionProtocol
    public let personalizedSearchSession: PersonalizedSearchSessionProtocol
    public let analyticsManager: AnalyticsService
    
    @MainActor public var lastFetchedTastePage: Int = 0
    
    public init(
        assistiveHostDelegate: AssistiveChatHost,
        placeSearchSession: PlaceSearchSessionProtocol,
        personalizedSearchSession: PersonalizedSearchSessionProtocol,
        analyticsManager: AnalyticsService
    ) {
        self.assistiveHostDelegate = assistiveHostDelegate
        self.placeSearchSession = placeSearchSession
        self.personalizedSearchSession = personalizedSearchSession
        self.analyticsManager = analyticsManager // This is fine
    }
    
    public func retrieveFsqUser(cacheManager:CacheManager) async throws {
        try await personalizedSearchSession.fetchManagedUserIdentity(cacheManager:cacheManager)
        try await personalizedSearchSession.fetchManagedUserAccessToken(cacheManager: cacheManager)
        
        if await personalizedSearchSession.fsqIdentity == nil {
            try await personalizedSearchSession.addFoursquareManagedUserIdentity(cacheManager: cacheManager)
        }
    }
    
    public func fetchDetails(for responses: [PlaceSearchResponse]) async throws -> [PlaceDetailsResponse] {
        return try await withThrowingTaskGroup(of: PlaceDetailsResponse?.self) { [placeSearchSession = self.placeSearchSession, analyticsManager = self.analyticsManager, previousDetails = self.assistiveHostDelegate.queryIntentParameters.queryIntents.last?.placeDetailsResponses] group in
            for response in responses {
                group.addTask {
                    let request = PlaceDetailsRequest(
                        fsqID: response.fsqID,
                        core: true,
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

                    // Await each call sequentially to keep Any-typed results from crossing isolation boundaries
                    let rawDetailsWrapped = try await placeSearchSession.details(for: request)
                    let tipsWrapped = try await placeSearchSession.tips(for: response.fsqID)
                    let photosWrapped = try await placeSearchSession.photos(for: response.fsqID)

                    // Tracking should not block or cross isolation with non-Sendable payloads
                    analyticsManager.track(event: "fetchDetails", properties: nil)

                    let tipsResponses = try PlaceResponseFormatter.placeTipsResponses(with: tipsWrapped, for: response.fsqID)
                    let photoResponses = try PlaceResponseFormatter.placePhotoResponses(with: photosWrapped, for: response.fsqID)

                    return try await PlaceResponseFormatter.placeDetailsResponse(
                        with: rawDetailsWrapped,
                        for: response,
                        placePhotosResponses: photoResponses,
                        placeTipsResponses: tipsResponses,
                        previousDetails: previousDetails
                    )
                }
            }

            var allResponses = [PlaceDetailsResponse]()
            for try await maybeResponse in group {
                if let response = maybeResponse {
                    allResponses.append(response)
                }
            }
            return allResponses
        }
    }
    
    public func fetchRelatedPlaces(for fsqID: String, cacheManager: CacheManager) async throws -> [PlaceSearchResponse] {
        return try await personalizedSearchSession.fetchRelatedVenues(for: fsqID, cacheManager: cacheManager)
    }

    public func fetchPlaceByID(fsqID: String) async throws -> ChatResult {
        let request = PlaceDetailsRequest(
            fsqID: fsqID,
            core: true,
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
        let rawDetailsWrapped = try await placeSearchSession.details(for: request)
        let tipsWrapped = try await placeSearchSession.tips(for: fsqID)
        let photosWrapped = try await placeSearchSession.photos(for: fsqID)
        
        // We need a base PlaceSearchResponse to create the ChatResult
        // In V3, we can't easily get a SearchResponse from ID without a search, 
        // but formatter can handle it if we mock a basic one or update it.
        // For now, let's create a ChatResult manually or update Formatter.
        
        let tipsResponses = try PlaceResponseFormatter.placeTipsResponses(with: tipsWrapped, for: fsqID)
        let photoResponses = try PlaceResponseFormatter.placePhotoResponses(with: photosWrapped, for: fsqID)
        
        // Mock a response since we only have details
        let mockResponse = PlaceSearchResponse(fsqID: fsqID, name: "", categories: [], latitude: 0, longitude: 0, address: "", addressExtended: "", country: "", dma: "", formattedAddress: "", locality: "", postCode: "", region: "", chains: [], link: "", childIDs: [], parentIDs: [])
        
        let details = try await PlaceResponseFormatter.placeDetailsResponse(
            with: rawDetailsWrapped,
            for: mockResponse,
            placePhotosResponses: photoResponses,
            placeTipsResponses: tipsResponses
        )
        
        return ChatResult(
            index: 0,
            identity: fsqID,
            title: details.name,
            list: "",
            icon: "📍",
            rating: 1.0,
            section: .topPicks,
            placeResponse: details.searchResponse,
        )
    }
    
    // MARK: Autocomplete Methods
    @MainActor
    public func autocompleteTastes(lastIntent: AssistiveChatHostIntent, currentTasteResults:[CategoryResult], cacheManager:CacheManager) async throws -> [CategoryResult] {
        var query = lastIntent.caption
        if let revisedQuery = lastIntent.queryParameters?["query"]?.value as? String {
            query = revisedQuery
        }
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let parameters = lastIntent.queryParameters?.compactMapValues { $0.value as? String }
        let tastesResponse = try await personalizedSearchSession.autocompleteTastes(caption: query, parameters: parameters, cacheManager: cacheManager)
        let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: tastesResponse)
        let results = await tasteCategoryResults(tastes: tastes, page: 0, currentTasteResults: currentTasteResults)
        return results
    }
    
    @MainActor
    public func refreshTastes(page: Int, currentTasteResults:[CategoryResult], cacheManager:CacheManager) async throws -> [CategoryResult] {
        let tastesResponse = try await personalizedSearchSession.fetchTastes(page: page, cacheManager: cacheManager)
        let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: tastesResponse)
        DispatchQueue.main.async {
            self.lastFetchedTastePage = page
        }
        let results = await tasteCategoryResults(tastes: tastes, page: page, currentTasteResults: currentTasteResults)
        return results
    }
        
    @MainActor private func tasteCategoryResults(tastes: [String], page: Int, currentTasteResults: [CategoryResult]) async -> [CategoryResult] {
        var results = currentTasteResults
        
        for (index, taste) in tastes.enumerated() {
            let section = await assistiveHostDelegate.section(for:taste)
            let chatResult = ChatResult(index: index, identity: taste, title: taste, list:"Taste", icon: "", rating: 1, section:section, placeResponse: nil, recommendedPlaceResponse: nil)
            let categoryResult = CategoryResult(identity:taste, parentCategory: taste, list:"Taste", icon: chatResult.icon, rating: 1, section:chatResult.section, categoricalChatResults: [chatResult])
            results.append(categoryResult)
        }
        
        return results
    }
    
    // MARK: Detail Intent
    
    public func detailIntent(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws {
        guard let placeSearchResponse = await intent.selectedPlaceSearchResponse else { return }
        
        let details = try await fetchDetails(for: [placeSearchResponse]).first
        let related = try await fetchRelatedPlaces(for: placeSearchResponse.fsqID, cacheManager: cacheManager)
        
        await MainActor.run {
            intent.selectedPlaceSearchDetails = details
            intent.relatedPlaceSearchResponses = related
            if let details = details {
                intent.placeDetailsResponses = [details]
            } else {
                intent.placeDetailsResponses = []
            }
        }
    }
        
    //MARK: - Request Building
    
    @MainActor
    public func placeSearchRequest(intent:AssistiveChatHostIntent) async ->PlaceSearchRequest {
        var query = intent.caption
        
        let ll = "\(intent.selectedDestinationLocation.location.coordinate.latitude),\(intent.selectedDestinationLocation.location.coordinate.longitude)"
        var openNow:Bool? = nil
        var openAt:String? = nil
        var nearLocation:String? = nil
        var minPrice = 1
        var maxPrice = 4
        var radius = 50000
        var sort:String? = nil
        var limit:Int = 50
        var categories = ""
        
        if let revisedQuery = intent.queryParameters?["query"]?.value as? String {
            query = revisedQuery
        }
        
        if let rawParameters = intent.queryParameters?["parameters"]?.value as? NSDictionary {
            
            
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
                categories = rawCategories.joined(separator: ",")
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
      
        // If we have explicit category IDs, prefer category-only search and omit the free-text query
        if !categories.isEmpty {
            query = ""
        }
        
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = PlaceSearchRequest(query:query, ll: ll, radius:radius, categories: categories, fields: nil, minPrice: minPrice, maxPrice: maxPrice, openAt: openAt, openNow: openNow, nearLocation: nearLocation, sort: sort, limit:limit)
        return request
    }
    
    @MainActor
    public func recommendedPlaceSearchRequest(intent:AssistiveChatHostIntent) async -> RecommendedPlaceSearchRequest
    {
        var query = intent.caption
        
        let ll = "\(intent.selectedDestinationLocation.location.coordinate.latitude),\(intent.selectedDestinationLocation.location.coordinate.longitude)"
        var openNow:Bool? = nil
        var minPrice = 1
        var maxPrice = 4
        var radius = 20000
        var limit:Int = 50
        var categories = ""
        var section:PersonalizedSearchSection? = nil
        var tags = AssistiveChatHostTaggedWord()
        
        if let revisedQuery = intent.queryParameters?["query"]?.value as? String {
            query = revisedQuery
        }
        
        if let rawParameters = intent.queryParameters?["parameters"]?.value as? NSDictionary {
            
            
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
                categories = rawCategories.joined(separator: ",")
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
        
        // If categories are present for recommendations, omit the free-text query to reduce ambiguity
        if !categories.isEmpty {
            query = ""
        }
        
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = RecommendedPlaceSearchRequest(query: query, ll: ll, radius: radius, categories: categories, minPrice:minPrice, maxPrice:maxPrice, openNow: openNow,  limit: limit, section:section ?? .topPicks, tags:tags)
        
        return request
    }
}

