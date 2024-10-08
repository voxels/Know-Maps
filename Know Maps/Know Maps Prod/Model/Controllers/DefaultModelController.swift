//
//  Defaultswift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

public final class DefaultModelController : ModelController, ObservableObject {
    
    // MARK: - Dependencies
    public var assistiveHostDelegate: AssistiveChatHost
    public var cacheManager:CacheManager
    public var locationService:LocationService
    public var locationProvider: LocationProvider
    public var placeSearchService: PlaceSearchService
    public var analyticsManager: AnalyticsService
    
    // MARK: - Published Properties
    
    @Published public var isFetchingResults:Bool = false
    
    // Selection States
    @Published public var selectedPersonalizedSearchSection:PersonalizedSearchSection?
    @Published public var selectedCategoryResult: CategoryResult.ID?
    @Published public var selectedSavedResult: CategoryResult.ID?
    @Published public var selectedTasteCategoryResult: CategoryResult.ID?
    @Published public var selectedListCategoryResult: CategoryResult.ID?
    @Published public var selectedCategoryChatResult: ChatResult.ID?
    @Published public var selectedPlaceChatResult: ChatResult.ID?
    @Published public var selectedDestinationLocationChatResult: LocationResult.ID?
    
    // Fetching States
    @Published public var isFetchingPlaceDescription: Bool = false
    
    // Results
    @Published public var industryResults = [CategoryResult]()
    @Published public var tasteResults = [CategoryResult]()
    @Published public var searchCategoryResults = [CategoryResult]()
    @Published public var placeResults = [ChatResult]()
    @Published public var recommendedPlaceResults = [ChatResult]()
    @Published public var relatedPlaceResults = [ChatResult]()
    @Published public var locationResults = [LocationResult]()
    @Published public var currentLocationResult:LocationResult = LocationResult(locationName: "Current Location", location: nil)
    
    
    // MARK: - Private Properties
    
    public var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    private var fetchingPlaceID: ChatResult.ID?
    private var sessionRetryCount: Int = 0

    // MARK: - Initializer
    
    public init(
        locationProvider: LocationProvider,
        analyticsManager: AnalyticsService
    ) {
        self.locationProvider = locationProvider
        self.analyticsManager = analyticsManager
        self.assistiveHostDelegate = AssistiveChatHostService(analyticsManager: analyticsManager)
        self.cacheManager = CloudCacheManager(cloudCache:CloudCacheService(analyticsManager: analyticsManager), analyticsManager: analyticsManager)
        self.placeSearchService = DefaultPlaceSearchService(assistiveHostDelegate: assistiveHostDelegate, placeSearchSession: PlaceSearchSession(), personalizedSearchSession: PersonalizedSearchSession(cacheManager: cacheManager), analyticsManager: analyticsManager)
        self.locationService = DefaultLocationService(locationProvider: locationProvider)
    }
    
    public func resetPlaceModel() {
        placeResults.removeAll()
        recommendedPlaceResults.removeAll()
        relatedPlaceResults.removeAll()
        analyticsManager.track(event:"resetPlaceModel", properties: nil)
    }
    
    public func categoricalSearchModel() async {
        let blendedResults =  categoricalResults()
        
        await MainActor.run {
            industryResults = blendedResults
        }
    }
    
    public func categoricalResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        
        for categoryCode in assistiveHostDelegate.categoryCodes {
            var newChatResults = [ChatResult]()
            for values in categoryCode.values {
                for value in values {
                    if let category = value["category"]{
                        let chatResult = ChatResult(title:category, list:category, icon: "", section:assistiveHostDelegate.section(for:category), placeResponse:nil, recommendedPlaceResponse: nil)
                        newChatResults.append(chatResult)
                    }
                }
            }
            
            for key in categoryCode.keys {
                newChatResults.append(ChatResult(title: key, list:key, icon:"", section:assistiveHostDelegate.section(for:key), placeResponse:nil, recommendedPlaceResponse: nil))
                
                if retval.contains(where: { checkResult in
                    return checkResult.parentCategory == key
                }) {
                    let existingResults = retval.compactMap { checkResult in
                        if checkResult.parentCategory == key {
                            return checkResult
                        }
                        return nil
                    }
                    
                    for result in existingResults {
                        if !result.categoricalChatResults.isEmpty {
                            newChatResults.append(contentsOf:result.categoricalChatResults)
                        }
                        retval.removeAll { checkResult in
                            return checkResult.parentCategory == key
                        }
                        
                        let newResult = CategoryResult(parentCategory: key, list:key, icon:"", section:assistiveHostDelegate.section(for:key), categoricalChatResults: newChatResults)
                        retval.append(newResult)
                    }
                    
                } else {
                    let newResult = CategoryResult(parentCategory: key, list:key, icon: "", section:assistiveHostDelegate.section(for:key), categoricalChatResults: newChatResults)
                    retval.append(newResult)
                }
            }
        }
        
        return retval
    }

    
    // MARK: - Filtered Results
    
    public var filteredRecommendedPlaceResults: [ChatResult] {
        return recommendedPlaceResults
    }
    
    public var filteredLocationResults: [LocationResult] {
        var results = [LocationResult]()
        results.append(currentLocationResult)
        results.append(contentsOf: cacheManager.cachedLocationResults)
        results.append(contentsOf: locationResults.filter({ result in
            !cacheManager.cachedLocationResults.contains(where: { $0.locationName == result.locationName })
        }))
        
        return results.sorted(by: { $0.locationName < $1.locationName })
    }
    
    public var filteredSourceLocationResults: [LocationResult] {
        return filteredLocationResults
    }
    
    public func filteredDestinationLocationResults(with searchText:String) async -> [LocationResult] {
        var results = filteredLocationResults
        let searchLocationResult = await locationChatResult(with: searchText, in:results)
        results.insert(searchLocationResult, at: 0)
        return results
    }
    
    public var filteredResults: [CategoryResult] {
        return industryResults.filter { !$0.categoricalChatResults.isEmpty }
    }
    
    public var filteredPlaceResults: [ChatResult] {
        return placeResults
    }
    
    // MARK: Place Result Methods
    
    public func placeChatResult(for id: ChatResult.ID) -> ChatResult? {
        if !recommendedPlaceResults.isEmpty {
            if let recommendedResult = recommendedPlaceResults.first(where: { $0.id == id }) {
                return recommendedResult
            }
        }
        
        return placeResults.first(where:{ $0.id == id })
    }
    
    public func placeChatResult(for fsqID: String) -> ChatResult? {
        return placeResults.first { $0.placeResponse?.fsqID == fsqID }
    }
    
    // MARK: Chat Result Methods
    
    public func chatResult(title: String) -> ChatResult? {
        return industryResults.compactMap { $0.result(title: title) }.first
    }
    
    public func categoryChatResult(for id: ChatResult.ID) -> ChatResult? {
        let allResults = industryResults.compactMap { $0.categoricalChatResults }
        for results in allResults {
            if let result = results.first(where: { $0.id == id || $0.parentId == id }) {
                return result
            }
        }
        return nil
    }
    
    public func tasteChatResult(for id: CategoryResult.ID) -> ChatResult? {
        return tasteResults.first(where: { $0.id == id })?.categoricalChatResults.first
    }
    
    public func categoricalChatResult(for id: CategoryResult.ID) -> ChatResult? {
        if let parentCategory = industryResults.flatMap({ [$0] + $0.children }).first(where: { $0.id == id }) {
            return parentCategory.categoricalChatResults.last
        }
        return nil
    }
    
    // MARK: Category Result Methods
    
    public func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return industryResults.flatMap { [$0] + $0.children }.first { $0.id == id }
    }
    
    public func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult? {
        return tasteResults.first { $0.id == id }
    }
    
    public func cachedCategoricalResult(for id:CategoryResult.ID)->CategoryResult? {
        return cacheManager.cachedIndustryResults.first { $0.id == id }
    }
    
    public func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cacheManager.cachedPlaceResults.first { $0.id == id }
    }
    
    public func cachedChatResult(for id: CategoryResult.ID) -> ChatResult? {
        if let parentCategory = cacheManager.allCachedResults.first(where: { $0.id == id }) {
            return parentCategory.categoricalChatResults.first
        }
        
        return nil
    }
    
    public func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cacheManager.cachedTasteResults.first { $0.id == id }
    }
    
    
    // MARK: - Location Handling
    
    public func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult? {
        return locationResults.first { $0.id == id }
    }
    
    public func locationChatResult(with title: String, in locationResults: [LocationResult]) async -> LocationResult {
        if let existingResult = locationResults.first(where: { $0.locationName == title }) {
            return existingResult
        }
        
        do {
            let placemarks = try await locationService.lookUpLocationName(name: title)
               if let firstPlacemark = placemarks.first {
                return LocationResult(locationName: title, location: firstPlacemark.location)
            }
        } catch {
            analyticsManager.trackError(error: error, additionalInfo: ["title": title])
        }
        
        return LocationResult(locationName: title)
    }
    
    public func checkSearchTextForLocations(with text: String) async throws -> [CLPlacemark]? {
        let tags = try assistiveHostDelegate.tags(for: text)
        return try await assistiveHostDelegate.nearLocationCoordinate(for: text, tags: tags)
    }
    
    @discardableResult
    public func refreshModel(query: String, queryIntents: [AssistiveChatHostIntent]?, locationResults: inout [LocationResult], currentLocationResult: LocationResult) async throws -> [ChatResult] {

        if let lastIntent = queryIntents?.last {
            return try await model(intent: lastIntent, locationResults: &locationResults, currentLocationResult: currentLocationResult)
        } else {
            let intent = assistiveHostDelegate.determineIntent(for: query, override: nil)
            let location = assistiveHostDelegate.lastLocationIntent()
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: query)
            let newIntent = AssistiveChatHostIntent(
                caption: query,
                intent: intent,
                selectedPlaceSearchResponse: nil,
                selectedPlaceSearchDetails: nil,
                placeSearchResponses: [],
                selectedDestinationLocationID: location?.selectedDestinationLocationID ?? currentLocationResult.id,
                placeDetailsResponses: nil,
                queryParameters: queryParameters
            )
            assistiveHostDelegate.appendIntentParameters(intent: newIntent)
            return try await model(intent: newIntent, locationResults: &locationResults, currentLocationResult: currentLocationResult)
        }
    }
    
    public func model(intent: AssistiveChatHostIntent, locationResults: inout [LocationResult], currentLocationResult: LocationResult) async throws -> [ChatResult] {
        switch intent.intent {
        case .Place:
            await placeQueryModel(intent: intent)
            analyticsManager.track(event:"modelPlaceQueryBuilt", properties: nil)
        case .Search:
            await searchQueryModel(intent: intent)
            try await placeSearchService.detailIntent(intent: intent)
            analyticsManager.track(event:"modelSearchQueryBuilt", properties: nil)
        case .Location:
            if let placemarks = try await checkSearchTextForLocations(with: intent.caption) {
                let locations = placemarks.map {
                    LocationResult(locationName: $0.name ?? "Unknown Location", location: $0.location)
                }
                
                var candidates = [LocationResult]()
                
                for location in locations {
                    let newLocationName = try await locationService.lookUpLocationName(name: location.locationName).first?.name ?? location.locationName
                    candidates.append(LocationResult(locationName: newLocationName, location: location.location))
                }
                
                let existingLocationNames = locationResults.map { $0.locationName }
                let newLocations = candidates.filter { !existingLocationNames.contains($0.locationName) }
                
                locationResults.append(contentsOf: newLocations)
                let ids = candidates.compactMap { $0.locationName.contains(intent.caption) ? $0.id : nil }
                await MainActor.run {
                    selectedDestinationLocationChatResult = ids.first
                }
            }
            
            try await cacheManager.refreshCache()
        case .AutocompleteSearch:
            if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult,
               let locationResult = locationChatResult(for: selectedDestinationLocationChatResult, in: locationResults),
               let finalLocation = locationResult.location {
                try await autocompletePlaceModel(caption: intent.caption, intent: intent, location: finalLocation)
                analyticsManager.track(event: "modelAutocompletePlaceModelBuilt", properties: nil)
            }
        case .AutocompleteTastes:
            tasteResults = try await placeSearchService.autocompleteTastes(lastIntent: intent, currentTasteResults: tasteResults)
            analyticsManager.track(event: "modelAutocompletePlaceModelBuilt", properties: nil)
        }
        
        return placeResults
    }
    
    
    public func searchIntent(intent:AssistiveChatHostIntent, location:CLLocation?) async throws {
        switch intent.intent {
            
        case .Place:
            if intent.selectedPlaceSearchResponse != nil {
                try await placeSearchService.detailIntent(intent: intent)
                if let detailsResponse = intent.selectedPlaceSearchDetails, let searchResponse = intent.selectedPlaceSearchDetails?.searchResponse {
                    intent.placeSearchResponses = [searchResponse]
                    intent.placeDetailsResponses = [detailsResponse]
                    intent.selectedPlaceSearchResponse = searchResponse
                    intent.selectedPlaceSearchDetails = detailsResponse
                }
                analyticsManager.track(event: "searchIntentWithSelectedPlace", properties: nil)
            } else {
                let request = await placeSearchService.placeSearchRequest(intent: intent, location:location)
                let rawQueryResponse = try await placeSearchService.placeSearchSession.query(request:request, location: location)
                let placeSearchResponses = try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse)
                intent.placeSearchResponses = placeSearchResponses
                try await placeSearchService.detailIntent(intent: intent)
                analyticsManager.track(event: "searchIntentWithPlace", properties: nil)
            }
        case .Search:
            let request = await placeSearchService.recommendedPlaceSearchRequest(intent: intent, location: location)
            let rawQueryResponse = try await placeSearchService.personalizedSearchSession.fetchRecommendedVenues(with:request, location: location)
                let recommendedPlaceSearchResponses = try PlaceResponseFormatter.recommendedPlaceSearchResponses(with: rawQueryResponse)
                intent.recommendedPlaceSearchResponses = recommendedPlaceSearchResponses
                
                if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
                    intent.placeSearchResponses = PlaceResponseFormatter.placeSearchResponses(from: recommendedPlaceSearchResponses)
                } else {
                    let request = await placeSearchService.placeSearchRequest(intent: intent, location:location)
                    let rawQueryResponse = try await placeSearchService.placeSearchSession.query(request:request, location: location)
                    let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse) : intent.placeSearchResponses
                    intent.placeSearchResponses = placeSearchResponses
                }
                analyticsManager.track(event: "searchIntentWithSearch", properties: nil)
        case .Location:
            break
        case .AutocompleteSearch:
            guard let location = location else {
                return
            }
            let autocompleteResponse = try await placeSearchService.personalizedSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, location: location)
                let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse) : intent.placeSearchResponses
                intent.placeSearchResponses = placeSearchResponses
            analyticsManager.track(event: "searchIntentWithPersonalizedAutocomplete", properties: nil)

        case .AutocompleteTastes:
            let autocompleteResponse = try await placeSearchService.personalizedSearchSession.autocompleteTastes(caption: intent.caption, parameters: intent.queryParameters)
                let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: autocompleteResponse)
                intent.tasteAutocompleteResponese = tastes
            analyticsManager.track(event: "searchIntentWithPersonalizedAutocompleteTastes", properties: nil)
        }
    }
    
    // MARK: Autocomplete Place Model
    
    @discardableResult
    public func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent, location: CLLocation) async throws -> [ChatResult] {
        let autocompleteResponse = try await placeSearchService.placeSearchSession.autocomplete(caption: caption, parameters: intent.queryParameters, location: location)
        let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
        intent.placeSearchResponses = placeSearchResponses
        
        await recommendedPlaceQueryModel(intent: intent)
        await relatedPlaceQueryModel(intent: intent)
        
        var chatResults = [ChatResult]()
        let allResponses = intent.placeSearchResponses
        for response in allResponses {
            let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, details: nil)
            chatResults.append(contentsOf: results)
        }
        
        
        await MainActor.run { [chatResults] in
            placeResults = chatResults
        }
        
        return chatResults
    }

    
    
    // MARK: Place Query Models
    
    @discardableResult
    public func placeQueryModel(intent: AssistiveChatHostIntent) async -> [ChatResult] {
        var chatResults = [ChatResult]()
        
        if let response = intent.selectedPlaceSearchResponse, let details = intent.selectedPlaceSearchDetails {
            let results = PlaceResponseFormatter.placeChatResults(
                for: intent,
                place: response,
                section: assistiveHostDelegate.section(for:intent.caption),
                list:intent.caption,
                details: details,
                recommendedPlaceResponse:nil
            )
            chatResults.append(contentsOf: results)
        } else {
            if !intent.placeSearchResponses.isEmpty {
                for response in intent.placeSearchResponses {
                    if !response.name.isEmpty {
                        let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section:assistiveHostDelegate.section(for:intent.caption), list:intent.caption, details: nil, recommendedPlaceResponse: nil)
                        chatResults.append(contentsOf: results)
                    }
                }
            }
        }
        
        await MainActor.run { [chatResults] in
            placeResults = chatResults
        }
        
        if let fsqID = intent.selectedPlaceSearchResponse?.fsqID, let placeChatResult = placeChatResult(for:fsqID) {
            await MainActor.run {
                selectedPlaceChatResult = placeChatResult.id
            }
        }
        
        await recommendedPlaceQueryModel(intent: intent)
        await relatedPlaceQueryModel(intent: intent)
        
        return chatResults
    }
    
    public func recommendedPlaceQueryModel(intent: AssistiveChatHostIntent) async {
        var recommendedChatResults = [ChatResult]()
        
        if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
            for response in recommendedPlaceSearchResponses {
                if !response.fsqID.isEmpty {
                    let placeResponse = PlaceSearchResponse(
                        fsqID: response.fsqID,
                        name: response.name,
                        categories: response.categories,
                        latitude: response.latitude,
                        longitude: response.longitude,
                        address: response.address,
                        addressExtended: response.formattedAddress,
                        country: response.country,
                        dma: response.neighborhood,
                        formattedAddress: response.formattedAddress,
                        locality: response.city,
                        postCode: response.postCode,
                        region: response.state,
                        chains: [],
                        link: "",
                        childIDs: [],
                        parentIDs: []
                    )
                    let results = PlaceResponseFormatter.placeChatResults(
                        for: intent,
                        place: placeResponse,
                        section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption,
                        details: nil,
                        recommendedPlaceResponse: response
                    )
                    recommendedChatResults.append(contentsOf: results)
                }
            }
        }
        
        await MainActor.run { [recommendedChatResults] in
            recommendedPlaceResults = recommendedChatResults
        }
    }
    
    public func relatedPlaceQueryModel(intent: AssistiveChatHostIntent) async {
        var relatedChatResults = [ChatResult]()
        
        if let relatedPlaceSearchResponses = intent.relatedPlaceSearchResponses, !relatedPlaceSearchResponses.isEmpty {
            for response in relatedPlaceSearchResponses {
                if !response.fsqID.isEmpty {
                    if response.fsqID == intent.selectedPlaceSearchResponse?.fsqID, let placeSearchResponse = intent.selectedPlaceSearchResponse {
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeSearchResponse,
                            section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption,
                            details: intent.selectedPlaceSearchDetails,
                            recommendedPlaceResponse:nil
                        )
                        relatedChatResults.append(contentsOf: results)
                    }else {
                        let placeResponse = PlaceSearchResponse(
                            fsqID: response.fsqID,
                            name: response.name,
                            categories: response.categories,
                            latitude: response.latitude,
                            longitude: response.longitude,
                            address: response.address,
                            addressExtended: response.formattedAddress,
                            country: response.country,
                            dma: response.neighborhood,
                            formattedAddress: response.formattedAddress,
                            locality: response.city,
                            postCode: response.postCode,
                            region: response.state,
                            chains: [],
                            link: "",
                            childIDs: [],
                            parentIDs: []
                        )
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeResponse,
                            section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption,
                            details: nil,
                            recommendedPlaceResponse: response
                        )
                        relatedChatResults.append(contentsOf: results)
                    }
                }
            }
        }
        await MainActor.run { [relatedChatResults] in
            relatedPlaceResults = relatedChatResults
        }
    }
    
    @discardableResult
    public func searchQueryModel(intent: AssistiveChatHostIntent) async -> [ChatResult] {
        var chatResults = [ChatResult]()
        
        let existingPlaceResults = placeResults.compactMap { $0.placeResponse }
        
        if existingPlaceResults == intent.placeSearchResponses,
           let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails,
           let selectedPlaceChatResult = selectedPlaceChatResult,
           let placeChatResult = placeChatResult(for: selectedPlaceChatResult) {
            var newResults = [ChatResult]()
            for placeResult in placeResults {
                if placeResult.placeResponse?.fsqID == placeChatResult.placeResponse?.fsqID, placeResult.placeDetailsResponse == nil {
                    var updatedPlaceResult = placeResult
                    updatedPlaceResult.replaceDetails(response: selectedPlaceSearchDetails)
                    newResults.append(updatedPlaceResult)
                } else {
                    newResults.append(placeResult)
                }
            }
            
            
            await MainActor.run { [newResults] in
                placeResults = newResults
            }
            
            await recommendedPlaceQueryModel(intent: intent)
            await relatedPlaceQueryModel(intent: intent)
            
            return chatResults
        }
        
        if let detailsResponses = intent.placeDetailsResponses {
            var allDetailsResponses = detailsResponses
            if let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails {
                allDetailsResponses.append(selectedPlaceSearchDetails)
            }
            for detailsResponse in allDetailsResponses {
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: detailsResponse.searchResponse,
                    section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption,
                    details: detailsResponse
                )
                chatResults.append(contentsOf: results)
            }
        }
        
        for response in intent.placeSearchResponses {
            var results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, details: nil)
            results = results.filter { result in
                !(intent.placeDetailsResponses?.contains { $0.fsqID == result.placeResponse?.fsqID } ?? false)
            }
            chatResults.append(contentsOf: results)
        }
        
        await MainActor.run { [chatResults] in
            placeResults = chatResults
        }
        
        await recommendedPlaceQueryModel(intent: intent)
        await relatedPlaceQueryModel(intent: intent)
        
        return chatResults
    }
    
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, locationResults: inout [LocationResult]) async throws {
       
            if parameters.queryIntents.last?.intent == .Location {
                let placemarks = try? await checkSearchTextForLocations(with: caption)
                
                if let placemarks = placemarks, let firstPlacemark = placemarks.first, let _ = firstPlacemark.location {
                    await MainActor.run {
                        queryParametersHistory.append(parameters)
                    }
                    let locations = placemarks.compactMap { placemark in
                        return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                    }
                    let existingLocationNames = locationResults.map { $0.locationName }
                    let newLocations = locations.filter { !existingLocationNames.contains($0.locationName) }
                    locationResults.append(contentsOf: newLocations)
                    analyticsManager.track(event:"foundPlacemarksInQuery", properties: nil)
                }
            }
            
            if let sourceLocationID = selectedDestinationLocationChatResult,
               let sourceLocationResult = locationChatResult(for: sourceLocationID, in:locationResults),
               let queryLocation = sourceLocationResult.location {
               let destinationPlacemarks = try await locationService.lookUpLocation(queryLocation)
                
                let existingLocationNames = locationResults.compactMap { $0.locationName }
                
                for queryPlacemark in destinationPlacemarks {
                    if let locality = queryPlacemark.locality, !existingLocationNames.contains(locality) {
                        var name = locality
                        if let neighborhood = queryPlacemark.subLocality {
                            name = "\(neighborhood), \(locality)"
                        }
                        let newLocationResult = LocationResult(locationName: name, location: queryPlacemark.location)
                        if !existingLocationNames.contains(name) {
                            locationResults.append(newLocationResult)
                        }
                    }
                }
            }
            
            if let sourceLocationID = selectedDestinationLocationChatResult,
               let sourceLocationResult = locationChatResult(for: sourceLocationID, in:locationResults),
               sourceLocationResult.location == nil {
               let destinationPlacemarks = try await locationService.lookUpLocationName(name: sourceLocationResult.locationName)
                
                let existingLocationNames = locationResults.compactMap { $0.locationName }
                
                for queryPlacemark in destinationPlacemarks {
                    if let locality = queryPlacemark.locality, !existingLocationNames.contains(locality) {
                        var name = locality
                        if let neighborhood = queryPlacemark.subLocality {
                            name = "\(neighborhood), \(locality)"
                        }
                        let newLocationResult = LocationResult(locationName: name, location: queryPlacemark.location)
                        locationResults.append(newLocationResult)
                }
            }
        }
    }
    
    public func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID?) async throws {
        guard let lastIntent = assistiveHostDelegate.queryIntentParameters?.queryIntents.last else {
            return
        }
        
        let queryParameters = try await assistiveHostDelegate.defaultParameters(for: placeChatResult.title)
        let newIntent = AssistiveChatHostIntent(caption: placeChatResult.title, intent: .Place, selectedPlaceSearchResponse: placeChatResult.placeResponse, selectedPlaceSearchDetails:placeChatResult.placeDetailsResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: selectedDestinationChatResultID, placeDetailsResponses: nil, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, queryParameters: queryParameters)
        
        
        guard placeChatResult.placeResponse != nil else {
            assistiveHostDelegate.updateLastIntentParameters(intent: newIntent)
            try await assistiveHostDelegate.receiveMessage(caption: newIntent.caption, isLocalParticipant: true)
            return
        }
        
        try await placeSearchService.detailIntent(intent: newIntent)
        
        assistiveHostDelegate.updateLastIntentParameters(intent: newIntent)
        
        if let queryIntentParameters = assistiveHostDelegate.queryIntentParameters {
            try await didUpdateQuery(with: placeChatResult.title, parameters: queryIntentParameters)
        }
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        
        var selectedDestinationChatResult = selectedDestinationLocationChatResult
        let selectedPlaceChatResult = selectedPlaceChatResult
        if selectedDestinationChatResult == nil, selectedPlaceChatResult == nil {
            
        } else if selectedDestinationChatResult == nil, selectedPlaceChatResult != nil {
            if let firstlocationResultID = locationResults.first?.id {
                selectedDestinationChatResult = firstlocationResultID
            } else {
                throw ChatResultViewModelError.missingSelectedDestinationLocationChatResult
            }
        } else {
            if let destinationChatResult = selectedDestinationChatResult, let _ = locationChatResult(for: destinationChatResult, in: locationResults) {
                
            } else if let lastIntent = assistiveHostDelegate.queryIntentParameters?.queryIntents.last  {
                let locationChatResult = locationChatResult(for: lastIntent.selectedDestinationLocationID ?? currentLocationResult.id, in:filteredLocationResults)
                selectedDestinationChatResult = locationChatResult?.id
                await MainActor.run {
                    selectedDestinationLocationChatResult = locationChatResult?.id
                }
            } else {
                throw ChatResultViewModelError.missingSelectedDestinationLocationChatResult
            }
        }
        
        if let lastIntent = queryParametersHistory.last?.queryIntents.last, lastIntent.intent != .Location {
            let locationChatResult =  locationChatResult(for: selectedDestinationChatResult ?? currentLocationResult.id, in:filteredLocationResults)
            
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant, locationResults: &locationResults)
            try await searchIntent(intent: lastIntent, location: locationChatResult?.location)
            try await didUpdateQuery(with: caption, parameters: parameters)
        } else if let lastIntent = queryParametersHistory.last?.queryIntents.last, lastIntent.intent == .Location {
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant, locationResults: &locationResults)
            try await searchIntent(intent: lastIntent, location: nil)
            try await didUpdateQuery(with: caption, parameters: parameters)
        } else {
            let intent:AssistiveChatHostService.Intent = assistiveHostDelegate.determineIntent(for: caption, override: nil)
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            assistiveHostDelegate.appendIntentParameters(intent: newIntent)
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant, locationResults: &locationResults)
            try await searchIntent(intent: newIntent, location: locationChatResult(with:caption,  in:filteredLocationResults).location!  )
            try await didUpdateQuery(with: caption, parameters: parameters)
            
        }
    }
    
    public func didUpdateQuery(with query:String, parameters: AssistiveChatHostQueryParameters) async throws {
        placeResults = try await refreshModel(query: query, queryIntents: parameters.queryIntents, locationResults: &locationResults, currentLocationResult: currentLocationResult)
    }
    
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) {
        queryParametersHistory.append(parameters)
    }
}
