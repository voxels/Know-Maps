//
//  ModelController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

// MARK: - ModelController

@MainActor
public protocol ModelController : Sendable {
    
    var assistiveHostDelegate: AssistiveChatHost { get }
    var locationService:LocationService { get }
    var placeSearchService: PlaceSearchService { get }
    var analyticsManager: AnalyticsService { get }
    var recommenderService:RecommenderService { get }
    var cacheManager:CacheManager { get }

    // MARK: - Published Properties
    
    // Selection States
    var selectedPersonalizedSearchSection:PersonalizedSearchSection? { get set }
    var selectedPlaceChatResultFsqId:String? { get set }
    var selectedDestinationLocationChatResult: LocationResult { get set }
    
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
    
    var queryParametersHistory:[AssistiveChatHostQueryParameters] { get set }
    
    // MARK: - Filtered Results
    var filteredRecommendedPlaceResults: [ChatResult] { get }
    
    func filteredLocationResults() -> [LocationResult]
        
    var filteredResults: [CategoryResult] { get }
    
    var filteredPlaceResults: [ChatResult] { get }
    
    // MARK: - Init
    init(
       cacheManager:CacheManager
   )
    
    func resetPlaceModel() async throws
    
    // MARK: - Industry Category Handling
    
    func categoricalSearchModel() async 
    
    func categoricalResults()->[CategoryResult]
    
    // MARK: - Location Handling
    
    func setSelectedLocation(_ result: LocationResult?)
    
    /// Retrieves a `LocationResult` for a given ID from the provided list.
    func locationChatResult(for id: LocationResult.ID, in locationResults: [LocationResult]) -> LocationResult?
    
    /// Retrieves or creates a `LocationResult` with the given title.
    func locationChatResult(with title: String, in locationResults: [LocationResult]) async -> LocationResult?
        
    // MARK: Place Chat Result Methods
    func placeChatResult(for id: ChatResult.ID) -> ChatResult?
    
    func placeChatResult(with fsqID: String) -> ChatResult?
    
    // MARK: Chat Result Methods
    
    func chatResult(title: String) -> ChatResult?
    
    func industryChatResult(for id: ChatResult.ID) -> ChatResult?
    
    func tasteChatResult(for id: CategoryResult.ID) -> ChatResult?
        
    // MARK: Category Result Methods
    
    func industryCategoryResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func tasteCategoryResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func cachedIndustryResult(for id:CategoryResult.ID)->CategoryResult?
    
    func cachedPlaceResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func cachedChatResult(for id: CategoryResult.ID) -> ChatResult?
    
    func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult?
    
    func cachedTasteResultTitle(_ title:String) -> CategoryResult?
    
    func cachedRecommendationData(for identity: String) -> RecommendationData?
    
    // MARK: - Model Building and Query Handling
    
    /// Refreshes the model based on the provided query and intents.
    func refreshModel(
        query: String,
        queryIntents: [AssistiveChatHostIntent]?, filters:[String:Any]
    ) async throws -> [ChatResult]
    
    /// Builds the model based on the given intent.
    func model(
        intent: AssistiveChatHostIntent
    ) async throws -> [ChatResult]
    
    // MARK: - Place Query Models
    
    /// Builds chat results for a place query intent.
    func placeQueryModel(intent: AssistiveChatHostIntent) async throws -> [ChatResult]
    
    /// Builds chat results for a search query intent.
    func searchQueryModel(intent: AssistiveChatHostIntent) async throws -> [ChatResult]
    
    /// Handles autocomplete place model creation.
    func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent) async throws -> [ChatResult]
    
    // MARK: - Message Handling
    /// Processes a search intent based on the given intent and location.
    func searchIntent(
        intent: AssistiveChatHostIntent
    ) async throws
    
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, filters:[String:Any], overrideIntent: AssistiveChatHostService.Intent?, selectedDestinationLocation: LocationResult?) async throws

    func didUpdateQuery(with query:String, parameters: AssistiveChatHostQueryParameters, filters:[String:Any]) async throws -> [ChatResult]

    func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResult:LocationResult, filters:[String:Any]) async throws
    
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) async
}
