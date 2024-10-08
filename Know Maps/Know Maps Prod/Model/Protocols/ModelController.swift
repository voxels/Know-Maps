//
//  ModelController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

// MARK: - ModelController

public protocol ModelController {
    
    var assistiveHostDelegate: AssistiveChatHost { get }
    var cacheManager:CacheManager { get }
    var locationService:LocationService { get }
    var locationProvider: LocationProvider { get }
    var placeSearchService: PlaceSearchService { get }
    var analyticsManager: AnalyticsService { get }
    
    // MARK: - Published Properties
    
    var isFetchingResults:Bool { get set }
    
    // Selection States
    var selectedPersonalizedSearchSection:PersonalizedSearchSection? { get set }
    var selectedCategoryResult: CategoryResult.ID? { get set }
    var selectedSavedResult: CategoryResult.ID? { get set }
    var selectedTasteCategoryResult: CategoryResult.ID? { get set }
    var selectedListCategoryResult: CategoryResult.ID? { get set }
    var selectedCategoryChatResult: ChatResult.ID? { get set }
    var selectedPlaceChatResult: ChatResult.ID? { get set }
    var selectedDestinationLocationChatResult: LocationResult.ID? { get set }
    
    // Fetching States
    var isFetchingPlaceDescription: Bool { get set }
    
    // Results
    var industryResults:[CategoryResult] { get set }
    var tasteResults:[CategoryResult] { get set }
    var searchCategoryResults:[CategoryResult] { get set }
    var placeResults:[ChatResult] { get set }
    var recommendedPlaceResults:[ChatResult] { get set }
    var relatedPlaceResults:[ChatResult] { get set }
    var locationResults:[LocationResult] { get set }
    var currentLocationResult:LocationResult { get set }
    
    var queryParametersHistory:[AssistiveChatHostQueryParameters] { get set }
    
    // MARK: - Filtered Results
    var filteredRecommendedPlaceResults: [ChatResult] { get }
    
    var filteredLocationResults: [LocationResult] { get }
    
    var filteredSourceLocationResults: [LocationResult] { get }
    
    func filteredDestinationLocationResults(with searchText:String) async -> [LocationResult]
    
    var filteredResults: [CategoryResult] { get }
    
    var filteredPlaceResults: [ChatResult] { get }

    // MARK: - Init
    init(
        locationProvider: LocationProvider,
        analyticsManager: AnalyticsService
    ) 
    
    
    // MARK: - Location Handling
    
    /// Retrieves a `LocationResult` for a given ID from the provided list.
    func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult?
    
    /// Retrieves or creates a `LocationResult` with the given title.
    func locationChatResult(with title: String, in locationResults: [LocationResult]) async -> LocationResult
    
    /// Checks if the search text corresponds to any known locations.
    func checkSearchTextForLocations(with text: String) async throws -> [CLPlacemark]?
    
    // MARK: Place Chat Result Methods
    func placeChatResult(for id: ChatResult.ID) -> ChatResult?
    
    func placeChatResult(for fsqID: String) -> ChatResult?
    
    // MARK: Chat Result Methods
    
    func chatResult(title: String) -> ChatResult?
    
    func categoryChatResult(for id: ChatResult.ID) -> ChatResult?
    
    func tasteChatResult(for id: CategoryResult.ID) -> ChatResult?
    
    func categoricalChatResult(for id: CategoryResult.ID) -> ChatResult?
    
    // MARK: Category Result Methods
    
    func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func cachedCategoricalResult(for id:CategoryResult.ID)->CategoryResult?
    
    func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func cachedChatResult(for id: CategoryResult.ID) -> ChatResult?
    
    func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? 
    
    // MARK: - Model Building and Query Handling
    
    /// Refreshes the model based on the provided query and intents.
    func refreshModel(
        query: String,
        queryIntents: [AssistiveChatHostIntent]?,
        locationResults: inout [LocationResult],
        currentLocationResult: LocationResult
    ) async throws -> [ChatResult]
    
    /// Builds the model based on the given intent.
    func model(
        intent: AssistiveChatHostIntent,
        locationResults: inout [LocationResult],
        currentLocationResult: LocationResult
    ) async throws -> [ChatResult]
    
    // MARK: - Place Query Models
    
    /// Builds chat results for a place query intent.
    func placeQueryModel(intent: AssistiveChatHostIntent) async -> [ChatResult]
    
    /// Builds chat results for a search query intent.
    func searchQueryModel(intent: AssistiveChatHostIntent) async -> [ChatResult]
    
    /// Handles autocomplete place model creation.
    func autocompletePlaceModel(
        caption: String,
        intent: AssistiveChatHostIntent,
        location: CLLocation
    ) async throws -> [ChatResult]
    
    // MARK: - Message Handling
    
    /// Handles receiving a message and updates location results accordingly.
    func receiveMessage(
        caption: String,
        parameters: AssistiveChatHostQueryParameters,
        isLocalParticipant: Bool,
        locationResults: inout [LocationResult]
    ) async throws
    
    /// Processes a search intent based on the given intent and location.
    func searchIntent(
        intent: AssistiveChatHostIntent,
        location: CLLocation?
    ) async throws
}
