//
//  ModelController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

// MARK: - ModelController

public protocol ModelController : Sendable {
    
    var assistiveHostDelegate: AssistiveChatHost { get }
    var locationService:LocationService { get }
    var locationProvider: LocationProvider { get }
    var placeSearchService: PlaceSearchService { get }
    var analyticsManager: AnalyticsService { get }
    var recommenderService:RecommenderService { get }
    
    // MARK: - Published Properties
    
    // Selection States
    var selectedPersonalizedSearchSection:PersonalizedSearchSection? { get set }
    var selectedSavedResult: CategoryResult.ID? { get set }
    var selectedPlaceChatResult: ChatResult.ID? { get set }
    var selectedDestinationLocationChatResult: LocationResult.ID? { get set }
    
    // Fetching States
    var isFetchingPlaceDescription: Bool { get set }
    var isRefreshingPlaces:Bool { get set }
    var fetchMessage:String { get }
    
    // TabView
    var section:Int { get set }
    
    // Results
    var industryResults:[CategoryResult] { get set }
    var tasteResults:[CategoryResult] { get set }
    var placeResults:[ChatResult] { get set }
    var mapPlaceResults:[ChatResult] { get set }
    var recommendedPlaceResults:[ChatResult] { get set }
    var relatedPlaceResults:[ChatResult] { get set }
    var locationResults:[LocationResult] { get set }
    var currentlySelectedLocationResult:LocationResult { get set }
    
    var queryParametersHistory:[AssistiveChatHostQueryParameters] { get set }
    
    // MARK: - Filtered Results
    var filteredRecommendedPlaceResults: [ChatResult] { get }
    
    func filteredLocationResults(cacheManager:CacheManager) -> [LocationResult]
    
    func filteredDestinationLocationResults(with searchText:String, cacheManager:CacheManager) async -> [LocationResult]
    
    var filteredResults: [CategoryResult] { get }
    
    var filteredPlaceResults: [ChatResult] { get }
    
    var currentPOIs:[POI] { get }
    var currentTours:[Tour] { get }

    // MARK: - Init
    init(
        locationProvider: LocationProvider,
        analyticsManager: AnalyticsService,
        messagesDelegate:AssistiveChatHostMessagesDelegate
    )
    
    func resetPlaceModel() async throws
    
    // MARK: - Industry Category Handling
    
    func categoricalSearchModel() async 
    
    func categoricalResults()->[CategoryResult]
    
    // MARK: - Location Handling
    
    /// Retrieves a `LocationResult` for a given ID from the provided list.
    func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult?
    
    /// Retrieves or creates a `LocationResult` with the given title.
    func locationChatResult(with title: String, in locationResults: [LocationResult]) async -> LocationResult
    
    /// Checks if the search text corresponds to any known locations.
    func checkSearchTextForLocations(with text: String) async throws -> [CLPlacemark]?
    
    /// Sets the selected destination location and ensures `currentlySelectedLocationResult` stays in sync.
    /// If `id` is nil or not found, implementers should fall back to `currentlySelectedLocationResult` representing the current device location.
    mutating func setSelectedLocation(_ id: LocationResult.ID?)
    
    /// Sets the selected destination using cache-aware validation against filtered locations.
    mutating func setSelectedLocation(_ id: LocationResult.ID?, cacheManager: CacheManager)

    /// Validates that the selected destination and `currentlySelectedLocationResult` are consistent.
    /// If the selected destination is no longer valid (e.g., removed from cache), implementers should repair the state by selecting a valid destination or the current location.
    mutating func validateSelectedDestination(cacheManager: CacheManager)
    
    // MARK: Place Chat Result Methods
    func placeChatResult(for id: ChatResult.ID) -> ChatResult?
    
    func placeChatResult(with fsqID: String) -> ChatResult?
    
    // MARK: Chat Result Methods
    
    func chatResult(title: String) -> ChatResult?
    
    func categoryChatResult(for id: ChatResult.ID) -> ChatResult?
    
    func tasteChatResult(for id: CategoryResult.ID) -> ChatResult?
    
    func categoricalChatResult(for id: CategoryResult.ID) -> ChatResult?
    
    // MARK: Category Result Methods
    
    func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func cachedCategoricalResult(for id:CategoryResult.ID, cacheManager:CacheManager)->CategoryResult?
    
    func cachedPlaceResult(for id: CategoryResult.ID, cacheManager:CacheManager) -> CategoryResult?
    
    func cachedChatResult(for id: CategoryResult.ID, cacheManager:CacheManager) -> ChatResult?
    
    func cachedTasteResult(for id: CategoryResult.ID, cacheManager:CacheManager) -> CategoryResult?
    
    func cachedTasteResult(title:String, cacheManager:CacheManager) -> CategoryResult?
    
    func cachedRecommendationData(for identity: String, cacheManager: any CacheManager) -> RecommendationData?
    
    // MARK: - Model Building and Query Handling
    
    /// Refreshes the model based on the provided query and intents.
    func refreshModel(
        query: String,
        queryIntents: [AssistiveChatHostIntent]?, filters:[String:Any],
        cacheManager:CacheManager
    ) async throws -> [ChatResult]
    
    /// Builds the model based on the given intent.
    func model(
        intent: AssistiveChatHostIntent,
        cacheManager:CacheManager
    ) async throws -> [ChatResult]
    
    // MARK: - Place Query Models
    
    /// Builds chat results for a place query intent.
    func placeQueryModel(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws -> [ChatResult]
    
    /// Builds chat results for a search query intent.
    func searchQueryModel(intent: AssistiveChatHostIntent, cacheManager:CacheManager) async throws -> [ChatResult]
    
    /// Handles autocomplete place model creation.
    func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent) async throws -> [ChatResult]
    
    // MARK: - Message Handling
    
    /// Handles receiving a message and updates location results accordingly.
    func receiveMessage(
        caption: String,
        parameters: AssistiveChatHostQueryParameters,
        isLocalParticipant: Bool
    ) async throws
    
    /// Processes a search intent based on the given intent and location.
    func searchIntent(
        intent: AssistiveChatHostIntent,
        location: CLLocation,
        cacheManager:CacheManager
    ) async throws
    
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, filters:[String:Any], cacheManager:CacheManager) async throws

    func didUpdateQuery(with query:String, parameters: AssistiveChatHostQueryParameters, filters:[String:Any], cacheManager:CacheManager) async throws

    func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID?, filters:[String:Any],cacheManager:CacheManager) async throws
    
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) async
    
    func undoLastQueryParameterChange(filters:[String:Any], cacheManager:CacheManager) async throws
}

public extension ModelController {
    /// Default implementation to keep `currentlySelectedLocationResult` in sync
    /// with `selectedDestinationLocationChatResult`.
    mutating func setSelectedLocation(_ id: LocationResult.ID?) {
        // Debug logging to trace selection changes
        print("🗺️ ModelController setSelectedLocation called with: \(id?.uuidString ?? "nil")")
        let previous = selectedDestinationLocationChatResult
        print("🗺️ Previous selectedDestinationLocationChatResult: \(previous?.uuidString ?? "nil")")

        // If an id is provided, try to resolve it in known location results first
        if let id {
            if let match = locationChatResult(for: id, in: locationResults) {
                selectedDestinationLocationChatResult = id
                currentlySelectedLocationResult = match
                print("🗺️ New selectedDestinationLocationChatResult: \(id.uuidString)")
                return
            }
            // Invalid id — fall back to current selection
            print("🗺️ Warning: Attempted to set invalid location ID, falling back to current location")
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
            return
        }

        // If id is nil, ensure we have a valid selected destination id
        if selectedDestinationLocationChatResult == nil {
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
        }
    }

    /// Cache-aware selection setter that validates against filtered locations
    mutating func setSelectedLocation(_ id: LocationResult.ID?, cacheManager: CacheManager) {
        print("🗺️ ModelController (cache-aware) setSelectedLocation called with: \(id?.uuidString ?? "nil")")
        if let id {
            let filtered = filteredLocationResults(cacheManager: cacheManager)
            if let match = filtered.first(where: { $0.id == id }) {
                selectedDestinationLocationChatResult = id
                currentlySelectedLocationResult = match
                print("🗺️ New selectedDestinationLocationChatResult: \(id.uuidString)")
                return
            }
            print("🗺️ Warning: Attempted to set invalid location ID (cache-aware), falling back to current location")
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
            return
        }
        if selectedDestinationLocationChatResult == nil {
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
        }
    }

    /// Default validation to ensure the selected destination and current selection are consistent.
    mutating func validateSelectedDestination(cacheManager: CacheManager) {
        // If there's a selected id, ensure it exists in our known results; otherwise repair
        if let id = selectedDestinationLocationChatResult {
            if let match = locationChatResult(for: id, in: locationResults) {
                currentlySelectedLocationResult = match
            } else if let match = locationChatResult(for: id, in: filteredLocationResults(cacheManager: cacheManager)) {
                currentlySelectedLocationResult = match
            } else {
                // Repair: revert the selected id to the current selection
                selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
            }
        } else {
            // No selected id — set it to the current selection's id
            selectedDestinationLocationChatResult = currentlySelectedLocationResult.id
        }
    }
}
