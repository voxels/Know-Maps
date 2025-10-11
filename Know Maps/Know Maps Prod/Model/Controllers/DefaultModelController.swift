//
//  DefaultModelController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import SwiftUI
import CoreLocation
import AVKit

// MARK: - Model Controller Errors
public enum ModelControllerError: Error, LocalizedError {
    case invalidRecommendedPlaceResponse
    case missingLocationData
    case invalidAsyncOperation
    
    public var errorDescription: String? {
        switch self {
        case .invalidRecommendedPlaceResponse:
            return "Invalid recommended place response"
        case .missingLocationData:
            return "Missing location data"
        case .invalidAsyncOperation:
            return "Invalid async operation"
        }
    }
}

@MainActor
@Observable
public final class DefaultModelController : ModelController {
    
    // MARK: - Shared Instance
    private static var _shared: DefaultModelController?
    
    static var shared: DefaultModelController {
        if let existing = _shared {
            return existing
        }
        
        let instance = DefaultModelController(
            locationProvider: LocationProvider(),
            analyticsManager: SegmentAnalyticsService.shared, 
            messagesDelegate: ChatResultViewModel.shared
        )
        _shared = instance
        
        // Ensure the selected destination is initially set to current location
        if instance.selectedDestinationLocationChatResult == nil {
            instance.selectedDestinationLocationChatResult = instance.currentlySelectedLocationResult.id
        }
        
        return instance
    }
    
    // MARK: - Dependencies
    public let assistiveHostDelegate: AssistiveChatHost
    public let locationService:LocationService
    public let locationProvider: LocationProvider
    public let placeSearchService: PlaceSearchService
    public let analyticsManager: AnalyticsService
    public let recommenderService:RecommenderService
    public let supabaseService:SupabaseService
//    public var storyController:StoryRabbitController
    
    // MARK: - Published Properties
    
    // Selection States
    public var selectedPersonalizedSearchSection:PersonalizedSearchSection?
    public var selectedSavedResult: CategoryResult.ID?
    public var selectedPlaceChatResult: ChatResult.ID?
    public var selectedDestinationLocationChatResult: LocationResult.ID? {
        didSet {
            print("🗺️ selectedDestinationLocationChatResult changed from \(oldValue?.uuidString ?? "nil") to \(selectedDestinationLocationChatResult?.uuidString ?? "nil")")
            // Notify observers of the change
            analyticsManager.track(event: "selectedDestinationChanged", properties: [
                "oldValue": oldValue?.uuidString ?? "nil",
                "newValue": selectedDestinationLocationChatResult?.uuidString ?? "nil"
            ])
        }
    }
    
    // Fetching States
    public var isFetchingPlaceDescription: Bool = false
    public var isRefreshingPlaces:Bool = false
    public var fetchMessage:String = "Searching near Current Location..."
    
    // TabView
    public var section:Int = 0
    public var addItemSection:Int = 0
    
    // Results
    public var industryResults = [CategoryResult]()
    public var tasteResults = [CategoryResult]()
    public var placeResults = [ChatResult]()
    public var mapPlaceResults = [ChatResult]()
    public var recommendedPlaceResults = [ChatResult]()
    public var relatedPlaceResults = [ChatResult]()
    public var locationResults = [LocationResult]()
    public var currentlySelectedLocationResult:LocationResult = LocationResult(locationName: "Current Location", location:CLLocation(latitude: 37.333562, longitude:-122.004927))
    
    
    // MARK: - Private Properties
    
    public var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    private var fetchingPlaceID: ChatResult.ID?
    private var sessionRetryCount: Int = 0
    
    public var currentPOIs:[POI] = []
    public var currentTours:[Tour] = []
    
    // MARK: - Initializer
    
    public init(
        locationProvider: LocationProvider,
        analyticsManager: AnalyticsService,
        messagesDelegate: AssistiveChatHostMessagesDelegate
    ) {
        self.locationProvider = locationProvider
        self.analyticsManager = analyticsManager
        self.assistiveHostDelegate = AssistiveChatHostService(analyticsManager: analyticsManager, messagesDelegate: messagesDelegate)
        self.placeSearchService = DefaultPlaceSearchService(assistiveHostDelegate: assistiveHostDelegate, placeSearchSession: PlaceSearchSession(), personalizedSearchSession: PersonalizedSearchSession(), analyticsManager: analyticsManager)
        self.locationService = DefaultLocationService(locationProvider: locationProvider)
        self.recommenderService = DefaultRecommenderService()
        self.supabaseService = SupabaseService.shared
        
        // Initialize selectedDestinationLocationChatResult to current location
        self.selectedDestinationLocationChatResult = LocationResult(locationName: "Current Location", location:CLLocation(latitude: 37.333562, longitude:-122.004927)).id
        
        // Safer initialization of story controller
        let backgroundTaskId = UIBackgroundTaskIdentifier(rawValue: abs(Int.random(in: Int.min..<Int.max)))
//        self.storyController = StoryRabbitController(playerState: .loading, backgroundTask: backgroundTaskId)
        
        // Validate initial state
        _ = validateState()
        
        // Ensure industry results are populated on initialization
        Task {
            await categoricalSearchModel()
        }
    }
    
    // MARK: - Consolidated State Management
    
    /// Centralized method for updating all results to ensure consistency
    private func updateAllResults(
        industry: [CategoryResult]? = nil,
        taste: [CategoryResult]? = nil,
        places: [ChatResult]? = nil,
        mapPlaces: [ChatResult]? = nil,
        recommended: [ChatResult]? = nil,
        related: [ChatResult]? = nil,
        locations: [LocationResult]? = nil,
        appendLocations: Bool = false,
        selectedPlace: ChatResult.ID? = nil,
        selectedLocation: LocationResult.ID? = nil,
        clearAll: Bool = false
    ) {
        if clearAll {
            industryResults.removeAll()
            tasteResults.removeAll()
            placeResults.removeAll()
            mapPlaceResults.removeAll()
            recommendedPlaceResults.removeAll()
            relatedPlaceResults.removeAll()
            locationResults.removeAll()
            selectedPlaceChatResult = nil
            selectedDestinationLocationChatResult = nil
        }
        
        if let industry = industry { industryResults = industry }
        if let taste = taste { tasteResults = taste }
        if let places = places { placeResults = places }
        if let mapPlaces = mapPlaces { mapPlaceResults = mapPlaces }
        if let recommended = recommended { recommendedPlaceResults = recommended }
        if let related = related { relatedPlaceResults = related }
        
        if let locations = locations {
            if appendLocations {
                let existingLocationNames = locationResults.map { $0.locationName }
                let newLocations = locations.filter { !existingLocationNames.contains($0.locationName) }
                locationResults.append(contentsOf: newLocations)
            } else {
                locationResults = locations
            }
        }
        
        if let selectedPlace = selectedPlace { selectedPlaceChatResult = selectedPlace }
        if let selectedLocation = selectedLocation { selectedDestinationLocationChatResult = selectedLocation }
    }
    
    /// Safely update location state
    public func setSelectedLocation(_ locationID: LocationResult.ID?) {
        print("🗺️ ModelController setSelectedLocation called with: \(locationID?.uuidString ?? "nil")")
        print("🗺️ Previous selectedDestinationLocationChatResult: \(selectedDestinationLocationChatResult?.uuidString ?? "nil")")
        
        // Validate that the locationID exists in our results before setting it
        if let locationID = locationID {
            let allLocationResults = locationResults + [currentlySelectedLocationResult]
            if allLocationResults.contains(where: { $0.id == locationID }) {
                selectedDestinationLocationChatResult = locationID
            } else {
                print("🗺️ Warning: Attempted to set invalid location ID, falling back to current location")
                selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
            }
        } else {
            // If nil is passed, default to current location
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
        }
        
        print("🗺️ New selectedDestinationLocationChatResult: \(selectedDestinationLocationChatResult?.uuidString ?? "nil")")
    }
    
    /// Ensure the selected destination is always valid
    public func validateSelectedDestination(cacheManager: CacheManager) {
        guard let selectedID = selectedDestinationLocationChatResult else {
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
            return
        }
        
        let allResults = filteredLocationResults(cacheManager: cacheManager)
        if !allResults.contains(where: { $0.id == selectedID }) {
            print("🗺️ Invalid selected destination detected, resetting to current location")
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
        }
    }
    
    /// Get the CLLocation for the currently selected destination
    public func getSelectedDestinationLocation(cacheManager: CacheManager) -> CLLocation {
        print("🗺️ getSelectedDestinationLocation called")
        print("🗺️ Current selectedDestinationLocationChatResult: \(selectedDestinationLocationChatResult?.uuidString ?? "nil")")
        
        guard let selectedID = selectedDestinationLocationChatResult else {
            print("🗺️ No selected destination, using current location")
            return currentlySelectedLocationResult.location ?? locationService.currentLocation()
        }
        
        let filteredResults = filteredLocationResults(cacheManager: cacheManager)
        print("🗺️ Filtered location results count: \(filteredResults.count)")
        print("🗺️ Looking for location with ID: \(selectedID.uuidString)")
        
        for (index, result) in filteredResults.enumerated() {
            print("🗺️ Result \(index): \(result.locationName) - ID: \(result.id.uuidString)")
        }
        
        if let selectedLocation = filteredResults.first(where: { $0.id == selectedID }),
           let location = selectedLocation.location {
            print("🗺️ Using selected destination: \(selectedLocation.locationName) at \(location.coordinate)")
            return location
        }
        
        print("🗺️ Selected destination not found in filteredResults, fallback to current location")
        // Fallback to current location if selected destination is not found
        return currentlySelectedLocationResult.location ?? locationService.currentLocation()
    }
    
    /// Set the selected location and return the CLLocation synchronously to avoid race conditions
    public func setSelectedLocationAndGetLocation(_ locationID: LocationResult.ID?, cacheManager: CacheManager) -> CLLocation {
        print("🗺️ setSelectedLocationAndGetLocation called with: \(locationID?.uuidString ?? "nil")")
        setSelectedLocation(locationID)
        
        // Immediately get the location to avoid race conditions
        return getSelectedDestinationLocation(cacheManager: cacheManager)
    }
    
    /// Validate internal state consistency
    private func validateState() -> Bool {
        // Check for state consistency
        let hasValidCurrentLocation = currentlySelectedLocationResult.location != nil
//        let hasValidStoryController = storyController.playerState != .error
        
        if !hasValidCurrentLocation {
            analyticsManager.track(event: "invalidCurrentLocation", properties: nil)
        }
        
//        if !hasValidStoryController {
//            analyticsManager.track(event: "invalidStoryController", properties: nil)
//        }
//        
//        return hasValidCurrentLocation && hasValidStoryController
        return hasValidCurrentLocation
    }
    
    public func resetPlaceModel() async throws {
        let preservedSelectedDestination = selectedDestinationLocationChatResult

        // Clear all state consistently
        updateAllResults(clearAll: true)

        // Restore previously selected destination after clearing state
        if let preservedSelectedDestination {
            selectedDestinationLocationChatResult = preservedSelectedDestination
        } else {
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
        }
        
        // Fetch new data
        currentPOIs = try await SupabaseService.shared.fetchPOIs()
        currentTours = try await SupabaseService.shared.fetchTours()
        
        // Always repopulate industry results after reset
        await categoricalSearchModel()
        
        analyticsManager.track(event:"resetPlaceModel", properties: nil)
    }
    
    
    public func categoricalSearchModel() async {
        let blendedResults = categoricalResults()
        updateAllResults(industry: blendedResults)
    }
    
    /// Ensures industry results are populated if they're empty
    public func ensureIndustryResultsPopulated() async {
        if industryResults.isEmpty {
            await categoricalSearchModel()
        }
    }
    
    public func categoricalResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        var categoryMap = [String: Int]() // For efficient lookup
        
        for categoryCode in assistiveHostDelegate.categoryCodes {
            var newChatResults = [ChatResult]()
            for values in categoryCode.values {
                for index in 0..<values.count {
                    let value = values[index]
                    if let category = value["category"]{
                        let chatResult = ChatResult(index: index, identity: category, title:category, list:category, icon: "", rating: 1, section:assistiveHostDelegate.section(for:category), placeResponse:nil, recommendedPlaceResponse: nil)
                        newChatResults.append(chatResult)
                    }
                }
            }
            
            let keys = Array(categoryCode.keys.sorted())
            for index in 0..<keys.count {
                let key = keys[index]
                newChatResults.append(ChatResult(index:index,identity: key, title: key, list:key, icon:"", rating: 1, section:assistiveHostDelegate.section(for:key), placeResponse:nil, recommendedPlaceResponse: nil))
                
                if let existingIndex = categoryMap[key] {
                    // Update existing result
                    let existingResult = retval[existingIndex]
                    if !existingResult.categoricalChatResults.isEmpty {
                        newChatResults.append(contentsOf: existingResult.categoricalChatResults)
                    }
                    
                    let newResult = CategoryResult(identity:key, parentCategory: key, list:key, icon:"", rating:1, section:assistiveHostDelegate.section(for:key), categoricalChatResults: newChatResults)
                    retval[existingIndex] = newResult
                } else {
                    // Add new result
                    let newResult = CategoryResult(identity: key, parentCategory: key, list:key, icon: "", rating: 1, section:assistiveHostDelegate.section(for:key), categoricalChatResults: newChatResults)
                    categoryMap[key] = retval.count
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
    
    public func filteredLocationResults(cacheManager:CacheManager) -> [LocationResult] {
        var results = [LocationResult]()
        
        // Always include current location first
        results.append(currentlySelectedLocationResult)
        
        // Add cached locations
        results.append(contentsOf: cacheManager.cachedLocationResults)
        
        // Add location results that aren't already in cache
        results.append(contentsOf: locationResults.filter({ result in
            !cacheManager.cachedLocationResults.contains(where: { $0.locationName.lowercased() == result.locationName.lowercased() })
        }))
        
        let sortedResults = results.sorted(by: { $0.locationName < $1.locationName })
        
        print("🗺️ filteredLocationResults returning \(sortedResults.count) results:")
        for (index, result) in sortedResults.enumerated() {
            print("🗺️   \(index): \(result.locationName) - ID: \(result.id.uuidString) - hasLocation: \(result.location != nil)")
        }
        
        return sortedResults
    }
    
    public func filteredDestinationLocationResults(with searchText:String, cacheManager:CacheManager) async -> [LocationResult] {
        var results = filteredLocationResults(cacheManager: cacheManager)
        let searchLocationResult = await locationChatResult(with: searchText, in:results)
        results.insert(searchLocationResult, at: 0)
        return results
    }
    
    public var filteredResults: [CategoryResult] {
        // Ensure industry results are populated before filtering
        if industryResults.isEmpty {
            Task {
                await ensureIndustryResultsPopulated()
            }
        }
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
        
        if !placeResults.isEmpty {
            if let placeResult = placeResults.first(where: { $0.id == id }) {
                return placeResult
            }
        }
        
        if !relatedPlaceResults.isEmpty {
            if let recommendedResult = relatedPlaceResults.first(where: { $0.id == id }) {
                return recommendedResult
            }
        }
        
        return nil
    }
    
    public func placeChatResult(with fsqID: String) -> ChatResult? {
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
    
    public func cachedCategoricalResult(for id:CategoryResult.ID, cacheManager:CacheManager)->CategoryResult? {
        return cacheManager.cachedIndustryResults.first { $0.id == id }
    }
    
    public func cachedPlaceResult(for id: CategoryResult.ID, cacheManager:CacheManager) -> CategoryResult? {
        return cacheManager.cachedPlaceResults.first { $0.id == id }
    }
    
    public func cachedChatResult(for id: CategoryResult.ID, cacheManager:CacheManager) -> ChatResult? {
        if let parentCategory = cacheManager.allCachedResults.first(where: { $0.id == id }) {
            return parentCategory.categoricalChatResults.first
        }
        
        return nil
    }
    
    public func cachedTasteResult(for id: CategoryResult.ID, cacheManager:CacheManager) -> CategoryResult? {
        return cacheManager.cachedTasteResults.first { $0.id == id }
    }
    
    
    public func cachedTasteResult(title: String, cacheManager: any CacheManager) -> CategoryResult? {
        return cacheManager.cachedTasteResults.first { $0.parentCategory == title}
    }
    
    public func cachedRecommendationData(for identity: String, cacheManager: any CacheManager) -> RecommendationData? {
        return cacheManager.cachedRecommendationData.first { $0.identity == identity }
    }
    
    // MARK: - Location Handling
    
    public func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult? {
        return locationResults.first { $0.id == id }
    }
    
    nonisolated public func locationChatResult(with title: String, in locationResults: [LocationResult]) async -> LocationResult {
        if let existingResult = locationResults.first(where: { $0.locationName == title }) {
            return existingResult
        }
        
        do {
            let placemarks = try await locationService.lookUpLocationName(name: title)
            if let firstPlacemark = placemarks.first {
                return LocationResult(locationName: title, location: firstPlacemark.location)
            }
        } catch {
            Task { @MainActor in
                analyticsManager.trackError(error: error, additionalInfo: ["title": title])
            }
        }
        
        return LocationResult(locationName: title)
    }
    
    nonisolated public func checkSearchTextForLocations(with text: String) async throws -> [CLPlacemark]? {
        let tags = try assistiveHostDelegate.tags(for: text)
        return try await assistiveHostDelegate.nearLocationCoordinate(for: text, tags: tags)
    }
    
    @discardableResult
    public func refreshModel(query: String, queryIntents: [AssistiveChatHostIntent]?, filters:[String:Any], cacheManager:CacheManager) async throws -> [ChatResult] {
        
        // Ensure industry results are always populated
        await ensureIndustryResultsPopulated()
        
        if let lastIntent = queryIntents?.last {
            return try await model(intent: lastIntent, cacheManager: cacheManager)
        } else {
            let intent = assistiveHostDelegate.determineIntent(for: query, override: nil)
            let location = assistiveHostDelegate.lastLocationIntent()
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: query,filters:filters )
            
            // Use selectedDestinationLocationChatResult as the search location
            let searchLocationID = selectedDestinationLocationChatResult ?? location?.selectedDestinationLocationID ?? currentlySelectedLocationResult.id
            
            let newIntent = AssistiveChatHostIntent(
                caption: query,
                intent: intent,
                selectedPlaceSearchResponse: nil,
                selectedPlaceSearchDetails: nil,
                placeSearchResponses: [],
                selectedDestinationLocationID: searchLocationID,
                placeDetailsResponses: nil,
                queryParameters: queryParameters
            )
            await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: self)
            return try await model(intent: newIntent, cacheManager: cacheManager)
        }
    }
    
    public func model(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws -> [ChatResult] {
        switch intent.intent {
        case .Place:
            try await placeQueryModel(intent: intent, cacheManager: cacheManager)
            analyticsManager.track(event:"modelPlaceQueryBuilt", properties: nil)
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
                
                updateAllResults(locations: newLocations, appendLocations: true)
                let ids = candidates.compactMap { $0.locationName.contains(intent.caption) ? $0.id : nil }
                setSelectedLocation(ids.first)
            }
            fallthrough
        case .Search:
            try await searchQueryModel(intent: intent, cacheManager: cacheManager)
            try await placeSearchService.detailIntent(intent: intent, cacheManager: cacheManager)
            analyticsManager.track(event:"modelSearchQueryBuilt", properties: nil)
        case .AutocompletePlaceSearch:
            try await autocompletePlaceModel(caption: intent.caption, intent: intent)
            analyticsManager.track(event: "modelAutocompletePlaceModelBuilt", properties: nil)
        case .AutocompleteTastes:
            let results = try await placeSearchService.autocompleteTastes(lastIntent: intent, currentTasteResults: tasteResults, cacheManager: cacheManager)
            updateAllResults(taste: results)
            analyticsManager.track(event: "modelAutocompletePlaceModelBuilt", properties: nil)
        }
        
        return placeResults
    }
    
    
    public func searchIntent(intent: AssistiveChatHostIntent, location:CLLocation, cacheManager:CacheManager) async throws {
        // Ensure the intent is using the currently selected destination
        if intent.selectedDestinationLocationID != selectedDestinationLocationChatResult {
            print("🔍 Updating intent destination from \(intent.selectedDestinationLocationID?.uuidString ?? "nil") to \(selectedDestinationLocationChatResult?.uuidString ?? "nil")")
            intent.selectedDestinationLocationID = selectedDestinationLocationChatResult
        }
        
        switch intent.intent {
            
        case .Place:
            if intent.selectedPlaceSearchResponse != nil {
                try await placeSearchService.detailIntent(intent: intent, cacheManager: cacheManager)
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
                try await placeSearchService.detailIntent(intent: intent, cacheManager: cacheManager)
                analyticsManager.track(event: "searchIntentWithPlace", properties: nil)
            }
        case .Location:
            fallthrough
        case .Search:
            let request = await placeSearchService.recommendedPlaceSearchRequest(intent: intent, location: location)
            do {
                let rawQueryResponse = try await placeSearchService.personalizedSearchSession.fetchRecommendedVenues(with:request, location: location, cacheManager: cacheManager)
                let recommendedPlaceSearchResponses = try PlaceResponseFormatter.recommendedPlaceSearchResponses(with: rawQueryResponse)
                intent.recommendedPlaceSearchResponses = recommendedPlaceSearchResponses
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: nil)
            }
            
            if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
                intent.placeSearchResponses = PlaceResponseFormatter.placeSearchResponses(from: recommendedPlaceSearchResponses)
            } else {
                let request = await placeSearchService.placeSearchRequest(intent: intent, location:location)
                let rawQueryResponse = try await placeSearchService.placeSearchSession.query(request:request, location: location)
                let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse) : intent.placeSearchResponses
                intent.placeSearchResponses = placeSearchResponses
            }
            
            if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, recommendedPlaceSearchResponses.isEmpty, intent.placeSearchResponses.isEmpty {
                
            }
            
            analyticsManager.track(event: "searchIntentWithSearch", properties: nil)

        case .AutocompletePlaceSearch:
            let autocompleteResponse = try await placeSearchService.placeSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, location: location)
            let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
            intent.placeSearchResponses = placeSearchResponses
            analyticsManager.track(event: "searchIntentWithPersonalizedAutocomplete", properties: nil)
            
        case .AutocompleteTastes:
            let autocompleteResponse = try await placeSearchService.personalizedSearchSession.autocompleteTastes(caption: intent.caption, parameters: intent.queryParameters, cacheManager: cacheManager)
            let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: autocompleteResponse)
            intent.tasteAutocompleteResponese = tastes
            analyticsManager.track(event: "searchIntentWithPersonalizedAutocompleteTastes", properties: nil)
        }
    }
    
    // MARK: Autocomplete Place Model
    
    @discardableResult
    public func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent) async throws -> [ChatResult] {
        var chatResults = [ChatResult]()
        
        if !intent.placeSearchResponses.isEmpty {
            for index in 0..<intent.placeSearchResponses.count {
                let response = intent.placeSearchResponses[index]
                if !response.name.isEmpty {
                    let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section:assistiveHostDelegate.section(for:intent.caption), list:intent.caption, index: index, rating: 1, details: nil, recommendedPlaceResponse: nil)
                    chatResults.append(contentsOf: results)
                }
            }
        }
        
        updateAllResults(places: chatResults, mapPlaces: chatResults)
        
        return chatResults
    }
    
    
    
    // MARK: Place Query Models
    
    @discardableResult
    public func placeQueryModel(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws -> [ChatResult] {
        
        var chatResults = [ChatResult]()
        
        if let response = intent.selectedPlaceSearchResponse, let details = intent.selectedPlaceSearchDetails {
            let results = PlaceResponseFormatter.placeChatResults(
                for: intent,
                place: response,
                section: assistiveHostDelegate.section(for:intent.caption),
                list:intent.caption, index: 0,
                rating: 1,
                details: details,
                recommendedPlaceResponse:nil
            )
            chatResults.append(contentsOf: results)
        } else {
            if !intent.placeSearchResponses.isEmpty {
                for index in 0..<intent.placeSearchResponses.count {
                    let response = intent.placeSearchResponses[index]
                    if !response.name.isEmpty {
                        let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section:assistiveHostDelegate.section(for:intent.caption), list:intent.caption, index: index, rating: 1, details: nil, recommendedPlaceResponse: nil)
                        chatResults.append(contentsOf: results)
                    }
                }
            }
        }
        
        Task {
            try await relatedPlaceQueryModel(intent: intent, cacheManager: cacheManager)
        }
        
        let mapResults = filteredPlaceResults.contains(where: {$0.identity == intent.selectedPlaceSearchResponse?.fsqID}) ? placeResults : chatResults
        let selectedPlace = placeResults.filter({ result in
            result.placeResponse?.fsqID == intent.selectedPlaceSearchResponse?.fsqID
        }).first?.id
        
        updateAllResults(
            places: chatResults,
            mapPlaces: mapResults,
            selectedPlace: selectedPlace
        )
        
        return chatResults
    }
    
    public func recommendedPlaceQueryModel(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws {
        var recommendedChatResults = [ChatResult]()
        
#if canImport(CreateML)
        if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses {
            if recommendedPlaceSearchResponses.count > 1 {
                if cacheManager.cachedTasteResults.count > 2 || cacheManager.cachedIndustryResults.count > 2  {

                    fetchMessage = "Personalizing results"
                    let trainingData = recommenderService.recommendationData(tasteCategoryResults:cacheManager.cachedTasteResults, industryCategoryResults: cacheManager.cachedIndustryResults, placeRecommendationData: cacheManager.cachedRecommendationData)
                    let model = try recommenderService.model(with: trainingData)
                    let testingData = recommenderService.testingData(with:recommendedPlaceSearchResponses)
                    let recommenderResults = try recommenderService.recommend(from: testingData, with: model)
                    
                    for index in 0..<recommendedPlaceSearchResponses.count {
                        let response = recommendedPlaceSearchResponses[index]
                        if !response.fsqID.isEmpty {
                            let rating = index < recommenderResults.count ? (recommenderResults[index].attributeRatings.first?.value ?? 1) : 1
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
                                section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: rating,
                                details: nil,
                                recommendedPlaceResponse: response
                            )
                            recommendedChatResults.append(contentsOf: results)
                        }
                    }
                } else {
                    for index in 0..<recommendedPlaceSearchResponses.count {
                        let response = recommendedPlaceSearchResponses[index]
                        if !response.fsqID.isEmpty {
                            let rating = 1.0
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
                                section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: rating,
                                details: nil,
                                recommendedPlaceResponse: response
                            )
                            recommendedChatResults.append(contentsOf: results)
                        }
                    }
                }
            } else if !recommendedPlaceSearchResponses.isEmpty {
                guard let response = recommendedPlaceSearchResponses.first else {
                    throw ModelControllerError.invalidRecommendedPlaceResponse
                }
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
                        section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: 0, rating: 1,
                        details: nil,
                        recommendedPlaceResponse: response
                    )
                    recommendedChatResults.append(contentsOf: results)
                }
            }
        }
        
        let sortedResults = recommendedChatResults.sorted(by: { result, checkResult in
            if result.rating == checkResult.rating {
                return result.index < checkResult.index
            }
            
            return result.rating > checkResult.rating
        })
        updateAllResults(recommended: sortedResults)
#else
        if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
            for index in 0..<recommendedPlaceSearchResponses.count {
                let response = recommendedPlaceSearchResponses[index]
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
                        section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: 0, rating: 1,
                        details: nil,
                        recommendedPlaceResponse: response
                    )
                    recommendedChatResults.append(contentsOf: results)
                }
            }
        }
        
        let sortedResults = recommendedChatResults.sorted(by: { result, checkResult in
            if result.rating == checkResult.rating {
                return result.index < checkResult.index
            }
            
            return result.rating > checkResult.rating
        })
        updateAllResults(recommended: sortedResults)
#endif
    }
    
    public func relatedPlaceQueryModel(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws {
        var relatedChatResults = [ChatResult]()
        
#if canImport(CreateML)
        if let relatedPlaceSearchResponses = intent.relatedPlaceSearchResponses, !relatedPlaceSearchResponses.isEmpty {
            
            var trainingData = recommenderService.recommendationData(tasteCategoryResults:cacheManager.cachedTasteResults, industryCategoryResults: cacheManager.cachedIndustryResults, placeRecommendationData: cacheManager.cachedRecommendationData)
            if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses {
                let additionalTrainingData = recommenderService.testingData(with: recommendedPlaceSearchResponses)
                trainingData.append(contentsOf: additionalTrainingData)
            }
            
            let model = try recommenderService.model(with: trainingData)
            let testingData = recommenderService.testingData(with:relatedPlaceSearchResponses)
            let recommenderResults = try recommenderService.recommend(from: testingData, with: model)
            
            for index in 0..<relatedPlaceSearchResponses.count {
                let response = relatedPlaceSearchResponses[index]
                if !response.fsqID.isEmpty {
                    if response.fsqID == intent.selectedPlaceSearchResponse?.fsqID, let placeSearchResponse = intent.selectedPlaceSearchResponse {
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeSearchResponse,
                            section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: 1,
                            details: intent.selectedPlaceSearchDetails,
                            recommendedPlaceResponse:response
                        )
                        relatedChatResults.append(contentsOf: results)
                    }else {
                        let rating = index < recommenderResults.count ? (recommenderResults[index].attributeRatings.first?.value ?? 1) : 1
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
                            section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: rating,
                            details: nil,
                            recommendedPlaceResponse: response
                        )
                        relatedChatResults.append(contentsOf: results)
                    }
                }
            }
        }
        
        let sortedResults = relatedChatResults.sorted(by: { result, checkResult in
            if result.rating == checkResult.rating {
                return result.index < checkResult.index
            }
            
            return result.rating > checkResult.rating
        })
        updateAllResults(related: sortedResults)
#else
        if let relatedPlaceSearchResponses = intent.relatedPlaceSearchResponses, !relatedPlaceSearchResponses.isEmpty {
            for index in 0..<relatedPlaceSearchResponses.count {
                let response = relatedPlaceSearchResponses[index]
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
                    section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: 1,
                    details: nil,
                    recommendedPlaceResponse: response
                )
                relatedChatResults.append(contentsOf: results)
            }
        }
        
        let sortedResults = relatedChatResults.sorted(by: { result, checkResult in
            if result.rating == checkResult.rating {
                return result.index < checkResult.index
            }
            return result.rating > checkResult.rating
        })
        updateAllResults(related: sortedResults)
#endif
    }
    
    @discardableResult
    public func searchQueryModel(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws -> [ChatResult] {
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
            
            try await recommendedPlaceQueryModel(intent: intent, cacheManager: cacheManager)
            
            updateAllResults(places: newResults, mapPlaces: newResults)
            
            return chatResults
        }
        
        if let detailsResponses = intent.placeDetailsResponses {
            var allDetailsResponses = detailsResponses
            if let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails {
                allDetailsResponses.append(selectedPlaceSearchDetails)
            }
            for index in 0..<allDetailsResponses.count {
                let detailsResponse = allDetailsResponses[index]
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: detailsResponse.searchResponse,
                    section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: 1,
                    details: detailsResponse
                )
                chatResults.append(contentsOf: results)
            }
        }
        
        for index in 0..<intent.placeSearchResponses.count {
            let response = intent.placeSearchResponses[index]
            var results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, section: assistiveHostDelegate.section(for: intent.caption), list: intent.caption, index: index, rating: 1, details: nil)
            results = results.filter { result in
                !(intent.placeDetailsResponses?.contains { $0.fsqID == result.placeResponse?.fsqID } ?? false)
            }
            chatResults.append(contentsOf: results)
        }
        
        try await recommendedPlaceQueryModel(intent: intent, cacheManager:cacheManager)
        
        updateAllResults(places: chatResults, mapPlaces: chatResults)
        
        return chatResults
    }
    
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        if parameters.queryIntents.last?.intent == .Location {
            do {
                let placemarks = try await checkSearchTextForLocations(with: caption)
                
                if let placemarks = placemarks, let firstPlacemark = placemarks.first, let _ = firstPlacemark.location {
                    queryParametersHistory.append(parameters)
                    let locations = placemarks.compactMap { placemark in
                        return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                    }
                    let existingLocationNames = locationResults.map { $0.locationName }
                    let newLocations = locations.filter { !existingLocationNames.contains($0.locationName) }
                    updateAllResults(locations: newLocations, appendLocations: true)
                    analyticsManager.track(event:"foundPlacemarksInQuery", properties: nil)
                }
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["caption": caption])
            }
        }
        
        if let sourceLocationID = selectedDestinationLocationChatResult,
           let sourceLocationResult = locationChatResult(for: sourceLocationID, in:locationResults),
           let queryLocation = sourceLocationResult.location {
            
            do {
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
                            updateAllResults(locations: [newLocationResult], appendLocations: true)
                        }
                    }
                }
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["sourceLocationID": sourceLocationID.uuidString])
            }
        }
        
        if let sourceLocationID = selectedDestinationLocationChatResult,
           let sourceLocationResult = locationChatResult(for: sourceLocationID, in:locationResults),
           sourceLocationResult.location == nil {
            
            do {
                let destinationPlacemarks = try await locationService.lookUpLocationName(name: sourceLocationResult.locationName)
                
                let existingLocationNames = locationResults.compactMap { $0.locationName }
                
                for queryPlacemark in destinationPlacemarks {
                    if let locality = queryPlacemark.locality, !existingLocationNames.contains(locality) {
                        var name = locality
                        if let neighborhood = queryPlacemark.subLocality {
                            name = "\(neighborhood), \(locality)"
                        }
                        let newLocationResult = LocationResult(locationName: name, location: queryPlacemark.location)
                        updateAllResults(locations: [newLocationResult], appendLocations: true)
                    }
                }
            } catch {
                analyticsManager.trackError(error: error, additionalInfo: ["locationName": sourceLocationResult.locationName])
            }
        }
    }
    
    public func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID?, filters:[String:Any], cacheManager:CacheManager) async throws {
        guard let lastIntent = assistiveHostDelegate.queryIntentParameters.queryIntents.last else {
            return
        }
        
        let queryParameters = try await assistiveHostDelegate.defaultParameters(for: placeChatResult.title, filters: filters)
        let newIntent = AssistiveChatHostIntent(caption: placeChatResult.title, intent: .Place, selectedPlaceSearchResponse: placeChatResult.placeResponse, selectedPlaceSearchDetails:placeChatResult.placeDetailsResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: selectedDestinationChatResultID, placeDetailsResponses: nil, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, relatedPlaceSearchResponses: lastIntent.relatedPlaceSearchResponses, queryParameters: queryParameters)
        
        
        guard placeChatResult.placeResponse != nil else {
            await assistiveHostDelegate.updateLastIntentParameters(intent: newIntent, modelController: self)
            try await assistiveHostDelegate.receiveMessage(caption: newIntent.caption, isLocalParticipant: true, filters: filters, cacheManager: cacheManager, modelController: self)
            return
        }
        
        try await placeSearchService.detailIntent(intent: newIntent, cacheManager: cacheManager)
        
        await assistiveHostDelegate.updateLastIntentParameters(intent: newIntent, modelController: self)
        
        let queryIntentParameters = assistiveHostDelegate.queryIntentParameters
        try await didUpdateQuery(with: placeChatResult.title, parameters: queryIntentParameters, filters: filters, cacheManager: cacheManager)
        
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, filters:[String:Any], cacheManager:CacheManager) async throws {
        
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
                
            } else if let lastIntent = assistiveHostDelegate.queryIntentParameters.queryIntents.last  {
                let locationChatResult = locationChatResult(for: lastIntent.selectedDestinationLocationID ?? currentlySelectedLocationResult.id, in:filteredLocationResults(cacheManager: cacheManager))
                selectedDestinationChatResult = locationChatResult?.id
                setSelectedLocation(locationChatResult?.id)
            } else {
                throw ChatResultViewModelError.missingSelectedDestinationLocationChatResult
            }
        }
        
        if let lastIntent = queryParametersHistory.last?.queryIntents.last, lastIntent.intent != .Location {
            let searchLocation = getSelectedDestinationLocation(cacheManager: cacheManager)
            
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            try await searchIntent(intent: lastIntent, location: searchLocation, cacheManager: cacheManager)
            try await didUpdateQuery(with: caption, parameters: parameters, filters: filters, cacheManager: cacheManager)
        } else if let lastIntent = queryParametersHistory.last?.queryIntents.last, lastIntent.intent == .Location {
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            try await searchIntent(intent: lastIntent, location: locationService.currentLocation(), cacheManager: cacheManager)
            try await didUpdateQuery(with: caption, parameters: parameters, filters: filters, cacheManager: cacheManager)
        } else {
            let intent:AssistiveChatHostService.Intent = assistiveHostDelegate.determineIntent(for: caption, override: nil)
            let queryParameters = try await assistiveHostDelegate.defaultParameters(for: caption ,filters: filters)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            await assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: self)
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            
            let searchLocation = getSelectedDestinationLocation(cacheManager: cacheManager)
            
            try await searchIntent(intent: newIntent, location: searchLocation, cacheManager: cacheManager)
            try await didUpdateQuery(with: caption, parameters: parameters, filters: filters, cacheManager: cacheManager)
        }
    }
    
    public func didUpdateQuery(with query:String, parameters: AssistiveChatHostQueryParameters, filters:[String:Any], cacheManager:CacheManager) async throws {
        _ = try await refreshModel(query: query, queryIntents: parameters.queryIntents, filters: filters, cacheManager: cacheManager)
    }
    
    
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) async {
        queryParametersHistory.append(parameters)
    }
    
    public func undoLastQueryParameterChange(filters:[String:Any], cacheManager:CacheManager) async throws {
        let previousHistory = queryParametersHistory.dropLast()
        let history = Array(previousHistory)
        if let lastHistory = history.last, let lastIntent = lastHistory.queryIntents.dropLast().last {
            await assistiveHostDelegate.updateLastIntentParameters(intent: lastIntent, modelController: self)
            try await receiveMessage(caption: lastIntent.caption, parameters: lastHistory, isLocalParticipant: true)
            
            let searchLocation = getSelectedDestinationLocation(cacheManager: cacheManager)
            try await searchIntent(intent: lastIntent, location: searchLocation, cacheManager: cacheManager)
            try await didUpdateQuery(with: lastIntent.caption, parameters: lastHistory, filters: filters, cacheManager: cacheManager)
        }
    }
}

