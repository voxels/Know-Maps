//
//  ChatResultViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation
import Segment

enum ChatResultViewModelError: Error {
    case missingLastIntent
    case missingSelectedPlaceSearchResponse
    case missingSelectedPlaceDetailsResponse
    case noAutocompleteResultsFound
    case missingCurrentLocation
    case missingSelectedDestinationLocationChatResult
    case retryTimeout
}

// MARK: - ChatResultViewModel

@MainActor
final class ChatResultViewModel: ObservableObject {
    // MARK: - Dependencies
    
    public weak var assistiveHostDelegate: AssistiveChatHostDelegate?
    public var placeSearchSession: PlaceSearchSession
    public var personalizedSearchSession: PersonalizedSearchSession
    public var locationProvider: LocationProvider
    public var cloudCache: CloudCache
    public var featureFlags: FeatureFlags
    public var analytics: Analytics?
    
    // MARK: - Published Properties
    
    @Published public var isRefreshingCache: Bool = false
    
    // Cached Results
    @Published public var cachedCategoryResults = [CategoryResult]()
    @Published public var cachedTasteResults = [CategoryResult]()
    @Published public var cachedPlaceResults = [CategoryResult]()
    @Published public var cachedListResults = [CategoryResult]()
    @Published public var allCachedResults = [CategoryResult]()
    @Published public var cachedLocationResults = [LocationResult]()
    
    // Selection States
    @Published public var selectedPersonalizedSearchSection:PersonalizedSearchSection = .none
    @Published public var selectedCategoryResult: CategoryResult.ID?
    @Published public var selectedSavedResult: CategoryResult.ID?
    @Published public var selectedTasteCategoryResult: CategoryResult.ID?
    @Published public var selectedListCategoryResult: CategoryResult.ID?
    @Published public var selectedCategoryChatResult: ChatResult.ID?
    @Published public var selectedPlaceChatResult: ChatResult.ID?
    @Published public var selectedSourceLocationChatResult: LocationResult.ID?
    @Published public var selectedDestinationLocationChatResult: LocationResult.ID?
    
    // Fetching States
    @Published public var isFetchingPlaceDescription: Bool = false
    @Published public var locationSearchText: String = ""
    
    // Results
    @Published public var categoryResults = [CategoryResult]()
    @Published public var tasteResults = [CategoryResult]()
    @Published public var searchCategoryResults = [CategoryResult]()
    @Published public var placeResults = [ChatResult]()
    @Published public var recommendedPlaceResults = [ChatResult]()
    @Published public var relatedPlaceResults = [ChatResult]()
    @Published public var locationResults = [LocationResult]()
    @Published public var currentLocationResult:LocationResult = LocationResult(locationName: "Current Location", location: nil)
    @Published public var lastFetchedTastePage: Int = 0
    @Published public var cacheFetchProgress:Double = 0

    
    // MARK: - Private Properties
    
    private var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    private var fetchingPlaceID: ChatResult.ID?
    private var sessionRetryCount: Int = 0
    private var cachedLocationRecords: [UserCachedRecord]?
    private var cachedTasteRecords: [UserCachedRecord]?
    private var cachedCategoryRecords: [UserCachedRecord]?
    private var cachedPlaceRecords: [UserCachedRecord]?
    private var cachedListRecords = [UserCachedRecord]()
    
    // MARK: - Initializer
    
    public init(
        assistiveHostDelegate: AssistiveChatHostDelegate? = nil,
        locationProvider: LocationProvider,
        cloudCache: CloudCache,
        featureFlags: FeatureFlags,
        analytics: Analytics? = nil
    ) {
        self.assistiveHostDelegate = assistiveHostDelegate
        self.locationProvider = locationProvider
        self.cloudCache = cloudCache
        self.featureFlags = featureFlags
        self.analytics = analytics
        self.placeSearchSession = PlaceSearchSession()
        self.personalizedSearchSession = PersonalizedSearchSession(cloudCache: cloudCache)
    }
    
    // MARK: - Session Management
    
    public func refreshSessions() async throws {
        if sessionRetryCount == 0 {
            sessionRetryCount += 1
            try await placeSearchSession.invalidateSession()
            sessionRetryCount = 0
        } else {
            throw ChatResultViewModelError.retryTimeout
        }
    }
    
    // MARK: - Location Handling
    
    public func currentLocationName() async throws -> String? {
        if let location = locationProvider.currentLocation() {
            return try await assistiveHostDelegate?.languageDelegate.lookUpLocation(location: location)?.first?.name
        }
        return nil
    }
    
    public func locationChatResult(for id: LocationResult.ID) -> LocationResult? {
        return filteredLocationResults.first { $0.id == id }
    }
    
    public func locationChatResult(with title: String) async -> LocationResult {
        if let existingResult = filteredLocationResults.first(where: { $0.locationName == title }) {
            return existingResult
        }
        
        do {
            if let placemarks = try await assistiveHostDelegate?.languageDelegate.lookUpLocationName(name: title),
               let firstPlacemark = placemarks.first {
                return LocationResult(locationName: title, location: firstPlacemark.location)
            }
        } catch {
            print(error)
            analytics?.track(name: "error: \(error)")
        }
        
        return LocationResult(locationName: title)
    }
    
    public func checkSearchTextForLocations(with text: String) async throws -> [CLPlacemark]? {
        let tags = try assistiveHostDelegate?.tags(for: text)
        return try await assistiveHostDelegate?.nearLocationCoordinate(for: text, tags: tags)
    }
    
    // MARK: - Filtered Results
    
    public var filteredRecommendedPlaceResults: [ChatResult] {
        let results = recommendedPlaceResults.filter { $0.placeDetailsResponse?.dateClosed?.isEmpty ?? true }
                
        return !results.isEmpty ? results : filteredPlaceResults
    }
    
    public var filteredLocationResults: [LocationResult] {
        var results = Set<LocationResult>()
        
        if !cachedLocationResults.isEmpty {
            results.formUnion(cachedLocationResults)
        }
        
        results.formUnion(locationResults)
        
        results.formUnion([currentLocationResult])
        
        return results.sorted { $0.locationName <= $1.locationName }
    }
    
    public var filteredSourceLocationResults: [LocationResult] {
        return filteredLocationResults
    }
    
    public func filteredDestinationLocationResults() async -> [LocationResult] {
        var results = filteredLocationResults
        let searchLocationResult = await locationChatResult(with: locationSearchText)
        results.insert(searchLocationResult, at: 0)
        return results
    }
    
    public var filteredResults: [CategoryResult] {
        return categoryResults.filter { !$0.categoricalChatResults.isEmpty }
    }
    
    public var filteredPlaceResults: [ChatResult] {
        return placeResults.filter { $0.placeDetailsResponse?.dateClosed?.isEmpty ?? true }
    }
    
    // MARK: - Cache Management
    
    // MARK: Refresh Cache
    
    @MainActor
    public func refreshCache(cloudCache: CloudCache) async throws {
        isRefreshingCache = true

        // Initialize progress variables
        let totalTasks = 3
        var completedTasks = 0

        // Define the timeout duration in seconds
        let timeoutInSeconds: UInt64 = 10

        // Create a task that encapsulates the entire operation
        let operationTask = Task {
            // Use a throwing task group to manage tasks and handle cancellations
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Define tasks with progress updates
                group.addTask {
                    try Task.checkCancellation()
                    await self.refreshCachedCategories(cloudCache: cloudCache)
                    try Task.checkCancellation()
                    await MainActor.run {
                        completedTasks += 1
                        let progress = Double(completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask {
                    try Task.checkCancellation()
                    await self.refreshCachedTastes(cloudCache: cloudCache)
                    try Task.checkCancellation()
                    await MainActor.run {
                        completedTasks += 1
                        let progress = Double(completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }
                group.addTask {
                    try Task.checkCancellation()
                    await self.refreshCachedPlaces(cloudCache: cloudCache)
                    try Task.checkCancellation()
                    await MainActor.run {
                        completedTasks += 1
                        let progress = Double(completedTasks) / Double(totalTasks)
                        self.cacheFetchProgress = progress
                    }
                }

                // Wait for all tasks to complete or handle cancellation
                try await group.waitForAll()
            }

            // Proceed with remaining tasks after the group tasks are done
            await self.refreshCachedLists(cloudCache: cloudCache)
            self.refreshCachedResults()
        }

        // Wait for the operation task to complete or cancel it after the timeout
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Add the main operation task
                group.addTask {
                    try await operationTask.value
                }
                // Add a timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutInSeconds * 1_000_000_000)
                    operationTask.cancel()
                    throw CancellationError()
                }
                // Wait for the first task to finish (either the operation or the timeout)
                try await group.next()
                // Cancel all remaining tasks
                group.cancelAll()
            }
        } catch is CancellationError {
            // Handle timeout or cancellation
            print("Refresh cache operation timed out or was cancelled")
        } catch {
            // Handle other errors
            print("An unexpected error occurred: \(error)")
        }

        isRefreshingCache = false
    }
    
    @MainActor
    private func refreshCachedCategories(cloudCache: CloudCache) async {
        do {
            cachedCategoryRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Category")
            cachedCategoryResults = savedCategoricalResults()
        } catch {
            print(error)
            analytics?.track(name: "error \(error)")
        }
    }
    
    @MainActor
    private func refreshCachedTastes(cloudCache: CloudCache) async {
        do {
            cachedTasteRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Taste")
            cachedTasteResults = savedTasteResults()
        } catch {
            print(error)
            analytics?.track(name: "error \(error)")
        }
    }
    
    @MainActor
    private func refreshCachedPlaces(cloudCache:CloudCache) async {
        do {
            self.cachedPlaceRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Place")
            self.cachedPlaceResults = self.savedPlaceResults()
        } catch {
            print(error)
            self.analytics?.track(name: "error \(error)")
        }
    }
    
    @MainActor
    private func refreshCachedLists(cloudCache: CloudCache) async {
        do {
            self.cachedListRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "List")
            self.cachedListResults = self.savedListResults()
        } catch {
            print(error)
            self.analytics?.track(name: "error \(error)")
        }
    }
    
    @MainActor
    public func refreshCachedLocations(cloudCache: CloudCache) async throws {
        let storedLocationRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Location")
        cachedLocationRecords = storedLocationRecords
        cachedLocationResults = savedLocationResults()
    }
    
    @MainActor
    public func refreshCachedResults() {
        allCachedResults = allSavedResults()
    }
    
    @MainActor
    public func removeCachedResults() {
        cachedListResults.removeAll()
        cachedPlaceResults.removeAll()
        cachedTasteResults.removeAll()
        cachedCategoryResults.removeAll()
        cachedLocationResults.removeAll()
        refreshCachedResults()
    }
    
    // MARK: Append Cached Data
    
    @MainActor
    public func appendCachedLocation(with record: UserCachedRecord) {
        cachedLocationRecords?.append(record)
        cachedLocationResults = savedLocationResults()
    }
    
    @MainActor
    public func appendCachedCategory(with record: UserCachedRecord) {
        cachedCategoryRecords?.append(record)
        cachedCategoryResults = savedCategoricalResults()
    }
    
    @MainActor
    public func appendCachedTaste(with record: UserCachedRecord) {
        cachedTasteRecords?.append(record)
        cachedTasteResults = savedTasteResults()
    }
    
    @MainActor
    public func appendCachedList(with record: UserCachedRecord) {
        cachedListRecords.append(record)
        cachedListResults = savedListResults()
    }
    
    @MainActor
    public func appendCachedPlace(with record: UserCachedRecord) {
        cachedPlaceRecords?.append(record)
        cachedPlaceResults = savedListResults()
    }
    
    // MARK: Cached Records Methods
    
    public func cachedCategories(contains category: String) -> Bool {
        return cachedCategoryRecords?.contains { $0.identity == category } ?? false
    }
    
    public func cachedTastes(contains taste: String) -> Bool {
        return cachedTasteRecords?.contains { $0.identity == taste } ?? false
    }
    
    public func cachedLocation(contains location: String) -> Bool {
        return cachedLocationResults.contains { $0.locationName == location }
    }
    
    public func cachedLocationIdentity(for location: CLLocation) -> String {
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
    
    
    
    // MARK: Fetch Cached Results by Group and Identity
    
    public func cachedResults(for group: String, identity: String) -> [UserCachedRecord]? {
        let allCachedRecords: [UserCachedRecord]? = {
            switch group {
            case "Category":
                return cachedCategoryRecords
            case "Taste":
                return cachedTasteRecords
            case "Location":
                return cachedLocationRecords
            case "Place":
                return cachedPlaceRecords
            case "List":
                return cachedListRecords
            default:
                return nil
            }
        }()
        
        return allCachedRecords?.filter { $0.group == group && $0.identity == identity }
    }
    
    
    
    // MARK: - Place Handling
    
    // MARK: Place Result Methods
    
    public func placeChatResult(for id: ChatResult.ID) -> ChatResult? {
        if cloudCache.hasPrivateCloudAccess {
            if let recommendedResult = recommendedPlaceResults.first(where: { $0.id == id }) {
                return placeResults.first { $0.placeResponse?.fsqID == recommendedResult.placeResponse?.fsqID }
            }
        }
        
        if currentLocationResult.id == id {
            return ChatResult(title: currentLocationResult.locationName, placeResponse: nil, recommendedPlaceResponse: nil)
        }
        
        return placeResults.first { $0.id == id }
    }
    
    public func placeChatResult(for fsqID: String) -> ChatResult? {
        if cloudCache.hasPrivateCloudAccess {
            if let recommendedResult = recommendedPlaceResults.first(where: { $0.placeResponse?.fsqID == fsqID }) {
                return recommendedResult
            }
            if let relatedResult = relatedPlaceResults.first(where: { $0.placeResponse?.fsqID == fsqID }) {
                return relatedResult
            }
        }
        
        return placeResults.first { $0.placeResponse?.fsqID == fsqID }
    }
    
    // MARK: Cached Chat Result Methods
    
    public func cachedChatResult(for id: CategoryResult.ID) -> ChatResult? {
        guard let parentCategory = allCachedResults.first(where: { $0.id == id }) else { return nil }
        return parentCategory.categoricalChatResults.first
    }
    
    public func cachedTasteResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cachedTasteResults.first { $0.id == id }
    }
    
    public func tasteResult(for id: CategoryResult.ID) -> CategoryResult? {
        return tasteResults.first { $0.id == id }
    }
    
    public func tasteChatResult(for id: CategoryResult.ID) -> ChatResult? {
        return tasteResults.first(where: { $0.id == id })?.categoricalChatResults.first
    }
    
    public func cachedListResult(for id: CategoryResult.ID) -> CategoryResult? {
        return cachedListResults.first { $0.id == id }
    }
    
    public func categoricalResult(for id: CategoryResult.ID) -> CategoryResult? {
        return categoryResults.flatMap { [$0] + $0.children }.first { $0.id == id }
    }
    
    public func categoricalChatResult(for id: CategoryResult.ID) -> ChatResult? {
        if let parentCategory = categoryResults.flatMap({ [$0] + $0.children }).first(where: { $0.id == id }) {
            return parentCategory.categoricalChatResults.last
        }
        return nil
    }
    
    public func chatResult(title: String) -> ChatResult? {
        return categoryResults.compactMap { $0.result(title: title) }.first
    }
    
    public func chatResult(for id: ChatResult.ID) -> ChatResult? {
        let allResults = categoryResults.compactMap { $0.categoricalChatResults }
        for results in allResults {
            if let result = results.first(where: { $0.id == id || $0.parentId == id }) {
                return result
            }
        }
        return chatResult(title: locationSearchText)
    }
    
    // MARK: - Saved Results
    
    private func savedCategoricalResults() -> [CategoryResult] {
        return cachedCategoryRecords?.map {
            let chatResults = [ChatResult(title: $0.title, placeResponse: nil, recommendedPlaceResponse: nil)]
            return CategoryResult(parentCategory: $0.title, list: $0.list, categoricalChatResults: chatResults)
        } ?? []
    }
    
    private func savedTasteResults() -> [CategoryResult] {
        return cachedTasteRecords?.map {
            let chatResults = [ChatResult(title: $0.title, placeResponse: nil, recommendedPlaceResponse: nil)]
            return CategoryResult(parentCategory: $0.title, list: $0.list, categoricalChatResults: chatResults)
        } ?? []
    }
    
    private func savedPlaceResults() -> [CategoryResult] {
        guard let savedRecords = cachedPlaceRecords else { return [] }
        return savedRecords.map { record in
            let chatResults: [ChatResult]
            if record.group == "Place" {
                let placeResponse = PlaceSearchResponse(
                    fsqID: record.identity,
                    name: "",
                    categories: [],
                    latitude: 0,
                    longitude: 0,
                    address: "",
                    addressExtended: "",
                    country: "",
                    dma: "",
                    formattedAddress: "",
                    locality: "",
                    postCode: "",
                    region: "",
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
                chatResults = [ChatResult(title: record.title, placeResponse: placeResponse, recommendedPlaceResponse: nil)]
            } else {
                chatResults = [ChatResult(title: record.title, placeResponse: nil, recommendedPlaceResponse: nil)]
            }
            return CategoryResult(parentCategory: record.title, list: record.list, categoricalChatResults: chatResults)
        }
    }
    
    private func savedListResults() -> [CategoryResult] {
        var temp = [String: (String, [ChatResult])]()
        for record in cachedListRecords {
            for placeResult in cachedPlaceResults {
                if let list = placeResult.list, list == record.identity {
                    if var existing = temp[record.title] {
                        existing.1.append(contentsOf: placeResult.categoricalChatResults)
                        temp[record.title] = existing
                    } else {
                        temp[record.title] = (list, placeResult.categoricalChatResults)
                    }
                }
            }
            
            for tasteResult in cachedTasteResults {
                if let list = tasteResult.list, list == record.identity {
                    if var existing = temp[record.title] {
                        existing.1.append(contentsOf: tasteResult.categoricalChatResults)
                        temp[record.title] = existing
                    } else {
                        temp[record.title] = (list, tasteResult.categoricalChatResults)
                    }
                }
            }
            
            if temp[record.title] == nil {
                temp[record.title] = (record.identity, [])
            }
        }
 
        return temp.map {
            CategoryResult(parentCategory: $0.key, list: $0.value.0, categoricalChatResults: $0.value.1)
        }.sorted {
            $0.parentCategory.lowercased() < $1.parentCategory.lowercased()
        }
    }
    
    private func allSavedResults() -> [CategoryResult] {
        var results = cachedCategoryResults + cachedTasteResults.filter({$0.list == nil}) + cachedListResults
        results.sort { $0.parentCategory.lowercased() < $1.parentCategory.lowercased() }
        return results
    }
    
    private func savedLocationResults() -> [LocationResult] {
        return cachedLocationRecords?.compactMap { record in
            let components = record.identity.split(separator: ",")
            if components.count == 2,
               let latitude = Double(components[0]),
               let longitude = Double(components[1]) {
                return LocationResult(locationName: record.title, location: CLLocation(latitude: latitude, longitude: longitude))
            }
            return nil
        } ?? []
    }
    
    // MARK: - Asynchronous Network Calls
    
    internal func fetchDetails(for responses: [PlaceSearchResponse]) async throws -> [PlaceDetailsResponse] {
        return try await withThrowingTaskGroup(of: PlaceDetailsResponse.self) { [weak self] group in
            guard let self = self else { return [] }
            for response in responses {
                group.addTask { @MainActor in
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
                    let rawDetailsResponse = try await self.placeSearchSession.details(for: request)
                    self.analytics?.track(name: "fetchDetails")
                    
                    if self.cloudCache.hasPrivateCloudAccess {
                        async let tipsRawResponse = self.placeSearchSession.tips(for: response.fsqID)
                        async let photosRawResponse = self.placeSearchSession.photos(for: response.fsqID)
                        
                        let (tipsData, photosData) = try await (tipsRawResponse, photosRawResponse)
                        let tipsResponses = try PlaceResponseFormatter.placeTipsResponses(with: tipsData, for: response.fsqID)
                        let photoResponses = try PlaceResponseFormatter.placePhotoResponses(with: photosData, for: response.fsqID)
                        
                        return try await PlaceResponseFormatter.placeDetailsResponse(
                            with: rawDetailsResponse,
                            for: response,
                            placePhotosResponses: photoResponses,
                            placeTipsResponses: tipsResponses,
                            previousDetails: self.assistiveHostDelegate?.queryIntentParameters?.queryIntents.last?.placeDetailsResponses,
                            cloudCache: self.cloudCache
                        )
                    } else {
                        return try await PlaceResponseFormatter.placeDetailsResponse(
                            with: rawDetailsResponse,
                            for: response,
                            previousDetails: self.assistiveHostDelegate?.queryIntentParameters?.queryIntents.last?.placeDetailsResponses,
                            cloudCache: self.cloudCache
                        )
                    }
                }
            }
            var allResponses = [PlaceDetailsResponse]()
            for try await response in group {
                allResponses.append(response)
            }
            return allResponses
        }
    }
    
    internal func fetchRelatedPlaces(for fsqID: String) async throws -> [RecommendedPlaceSearchResponse] {
        let rawRelatedVenuesResponse = try await personalizedSearchSession.fetchRelatedVenues(for: fsqID)
        return try PlaceResponseFormatter.relatedPlaceSearchResponses(with: rawRelatedVenuesResponse)
    }
    
    @discardableResult
    public func retrieveFsqUser() async throws -> Bool {
        personalizedSearchSession.fsqIdentity = try await personalizedSearchSession.fetchManagedUserIdentity()
        personalizedSearchSession.fsqAccessToken = try await personalizedSearchSession.fetchManagedUserAccessToken()
        
        if personalizedSearchSession.fsqIdentity == nil {
            return try await personalizedSearchSession.addFoursquareManagedUserIdentity()
        }

        return true
    }
    
    // MARK: - Model Building and Query Handling
    
    @MainActor
    public func resetPlaceModel() {
        selectedPlaceChatResult = nil
        placeResults.removeAll()
        recommendedPlaceResults.removeAll()
        relatedPlaceResults.removeAll()
        analytics?.track(name: "resetPlaceModel")
    }
    
    @MainActor
    public func refreshModel(queryIntents: [AssistiveChatHostIntent]? = nil) async throws {
        guard let chatHost = self.assistiveHostDelegate else { return }
        
        var caption = ""
        
        if let lastIntent = queryIntents?.last {
            caption = lastIntent.caption
            if let selectedPlaceChatResult = selectedPlaceChatResult,
               let placeChatResult = placeChatResult(for: selectedPlaceChatResult) {
                locationSearchText = placeChatResult.title
            } else {
                locationSearchText = caption
            }
            try await model(intent: lastIntent)
        } else {
            caption = locationSearchText
            let intent = chatHost.determineIntent(for: caption, override: nil)
            let location = chatHost.lastLocationIntent()
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(
                caption: caption,
                intent: intent,
                selectedPlaceSearchResponse: nil,
                selectedPlaceSearchDetails: nil,
                selectedRecommendedPlaceSearchResponse: nil,
                placeSearchResponses: [],
                selectedDestinationLocationID: location?.selectedDestinationLocationID ?? currentLocationResult.id,
                placeDetailsResponses: nil,
                queryParameters: queryParameters
            )
            chatHost.appendIntentParameters(intent: newIntent)
            try await model(intent: newIntent)
        }
    }
    
    public func model(intent: AssistiveChatHostIntent) async throws {
        guard let chatHost = self.assistiveHostDelegate else { return }
        
        switch intent.intent {
        case .Place:
            await placeQueryModel(intent: intent)
            analytics?.track(name: "modelPlaceQueryBuilt")
        case .Search:
            await searchQueryModel(intent: intent)
            try await detailIntent(intent: intent)
            analytics?.track(name: "modelSearchQueryBuilt")
        case .Location:
            if let placemarks = try await checkSearchTextForLocations(with: intent.caption) {
                let locations = placemarks.map {
                    LocationResult(locationName: $0.name ?? "Unknown Location", location: $0.location)
                }
                
                var candidates = [LocationResult]()
                
                for location in locations {
                    let newLocationName = try await chatHost.languageDelegate.lookUpLocationName(name: location.locationName)?.first?.name ?? location.locationName
                    candidates.append(LocationResult(locationName: newLocationName, location: location.location))
                }
                
                let existingLocationNames = locationResults.map { $0.locationName }
                let newLocations = candidates.filter { !existingLocationNames.contains($0.locationName) }
                
                Task { @MainActor in
                    locationResults.append(contentsOf: newLocations)
                    let ids = candidates.compactMap { $0.locationName.contains(intent.caption) ? $0.id : nil }
                    selectedDestinationLocationChatResult = ids.first
                }
            }
            
            Task {
                try await refreshCachedLocations(cloudCache: cloudCache)
            }
        case .AutocompleteSearch:
            do {
                if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult,
                   let locationResult = locationChatResult(for: selectedDestinationLocationChatResult),
                   let finalLocation = locationResult.location {
                    try await autocompletePlaceModel(caption: intent.caption, intent: intent, location: finalLocation)
                    analytics?.track(name: "modelAutocompletePlaceModelBuilt")
                }
            } catch {
                analytics?.track(name: "error \(error)")
                print(error)
            }
        case .AutocompleteTastes:
            do {
                    try await autocompleteTastes(lastIntent: intent)
                analytics?.track(name: "modelAutocompletePlaceModelBuilt")
            }
        }
    }
    
    @MainActor
    public func categoricalSearchModel() async {
        let blendedResults =  categoricalResults()
        
        categoryResults.removeAll()
        categoryResults = blendedResults
    }
    
    private func categoricalResults()->[CategoryResult] {
            guard let chatHost = assistiveHostDelegate else {
                return [CategoryResult]()
            }
            
            var retval = [CategoryResult]()
            
            for categoryCode in chatHost.categoryCodes {
                var newChatResults = [ChatResult]()
                for values in categoryCode.values {
                    for value in values {
                        if let category = value["category"]{
                            let chatResult = ChatResult(title:category, placeResponse:nil, recommendedPlaceResponse: nil)
                            newChatResults.append(chatResult)
                        }
                    }
                }
                
                for key in categoryCode.keys {
                    newChatResults.append(ChatResult(title: key, placeResponse:nil, recommendedPlaceResponse: nil))

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
                            
                            let newResult = CategoryResult(parentCategory: key, categoricalChatResults: newChatResults)
                            retval.append(newResult)
                        }
                        
                    } else {
                        let newResult = CategoryResult(parentCategory: key, categoricalChatResults: newChatResults)
                        retval.append(newResult)
                    }
                }
                
            }
            
            return retval
        }
    
    // MARK: Message Handling
    
    @MainActor
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        guard let chatHost = self.assistiveHostDelegate else {
            return
        }
        
        if parameters.queryIntents.last?.intent == .Location {
            let placemarks = try? await checkSearchTextForLocations(with: caption)
            
            if let placemarks = placemarks, let firstPlacemark = placemarks.first, let _ = firstPlacemark.location {
                queryParametersHistory.append(parameters)
                let locations = placemarks.compactMap { placemark in
                    return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                }
                let existingLocationNames = locationResults.map { $0.locationName }
                let newLocations = locations.filter { !existingLocationNames.contains($0.locationName) }
                locationResults.append(contentsOf: newLocations)
                analytics?.track(name: "foundPlacemarksInQuery")
            }
        }
        
        if let sourceLocationID = selectedDestinationLocationChatResult,
           let sourceLocationResult = locationChatResult(for: sourceLocationID),
           let queryLocation = sourceLocationResult.location,
           let destinationPlacemarks = try await chatHost.languageDelegate.lookUpLocation(location: queryLocation) {
            
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
           let sourceLocationResult = locationChatResult(for: sourceLocationID),
           sourceLocationResult.location == nil,
           let destinationPlacemarks = try await chatHost.languageDelegate.lookUpLocationName(name: sourceLocationResult.locationName) {
            
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
    
    @MainActor
    public func searchIntent(intent:AssistiveChatHostIntent, location:CLLocation?) async throws {
        switch intent.intent {
            
        case .Place:
            if let _ = intent.selectedPlaceSearchResponse {
                try await detailIntent(intent: intent)
                intent.selectedPlaceSearchResponse = intent.selectedPlaceSearchDetails?.searchResponse
                analytics?.track(name: "searchIntentWithSelectedPlace")
            } else {
                let request = await placeSearchRequest(intent: intent, location:location)
                let rawQueryResponse = try await placeSearchSession.query(request:request, location: location)
                let placeSearchResponses = try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse)
                intent.placeSearchResponses = placeSearchResponses
                try await detailIntent(intent: intent)
                analytics?.track(name: "searchIntentWithPlace")
            }
        case .Search:
            if cloudCache.hasPrivateCloudAccess {
                let request = await recommendedPlaceSearchRequest(intent: intent, location: location)
                let rawQueryResponse = try await personalizedSearchSession.fetchRecommendedVenues(with:request, location: location)
                let recommendedPlaceSearchResponses = try PlaceResponseFormatter.recommendedPlaceSearchResponses(with: rawQueryResponse)
                intent.recommendedPlaceSearchResponses = recommendedPlaceSearchResponses
                
                if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
                    intent.placeSearchResponses = PlaceResponseFormatter.placeSearchResponses(from: recommendedPlaceSearchResponses)
                } else {
                    let request = await placeSearchRequest(intent: intent, location:location)
                    let rawQueryResponse = try await placeSearchSession.query(request:request, location: location)
                    let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse) : intent.placeSearchResponses
                    intent.placeSearchResponses = placeSearchResponses
                }
                analytics?.track(name: "searchIntentWithSearch")
            } else {
                let request = await placeSearchRequest(intent: intent, location:location)
                let rawQueryResponse = try await placeSearchSession.query(request:request, location: location)
                let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse) : intent.placeSearchResponses
                intent.placeSearchResponses = placeSearchResponses
                analytics?.track(name: "searchIntentWithSearch")
            }
        case .Location:
            break
        case .AutocompleteSearch:
            guard let location = location else {
                return
            }
            if cloudCache.hasPrivateCloudAccess {
                let autocompleteResponse = try await personalizedSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, location: location)
                let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse) : intent.placeSearchResponses
                intent.placeSearchResponses = placeSearchResponses
                analytics?.track(name: "searchIntentWithPersonalizedAutocomplete")
            } else {
                let autocompleteResponse = try await placeSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, location: location)
                let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse) : intent.placeSearchResponses
                intent.placeSearchResponses = placeSearchResponses
                analytics?.track(name: "searchIntentWithAutocomplete")
            }
        case .AutocompleteTastes:
            if cloudCache.hasPrivateCloudAccess {
                let autocompleteResponse = try await personalizedSearchSession.autocompleteTastes(caption: intent.caption, parameters: intent.queryParameters)
                let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: autocompleteResponse)
                intent.tasteAutocompleteResponese = tastes
                analytics?.track(name: "searchIntentWithPersonalizedAutocompleteTastes")
            }
        }
    }
    
    
    // MARK: Autocomplete Methods
    
    @MainActor
    public func autocompleteTastes(lastIntent: AssistiveChatHostIntent) async throws {
        let query = lastIntent.caption
        let rawResponse = try await personalizedSearchSession.autocompleteTastes(caption: query, parameters: lastIntent.queryParameters)
        let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: rawResponse)
        tasteResults = tasteCategoryResults(with: tastes.map(\.text), page: 0)
        lastFetchedTastePage = 0
        try await refreshCachedTastes(cloudCache: cloudCache)
    }
    
    @MainActor
    public func refreshTastes(page: Int) async throws {
        if page > lastFetchedTastePage || tasteResults.isEmpty {
            let tastes = try await personalizedSearchSession.fetchTastes(page: page)
            tasteResults = tasteCategoryResults(with: tastes, page: page)
            lastFetchedTastePage = page
        } else {
            refreshTasteCategories(page: page)
        }
    }
    
    @MainActor
    public func refreshTasteCategories(page: Int) {
        let tastes = tasteResults.map { $0.parentCategory }
        tasteResults = tasteCategoryResults(with: tastes, page: page)
        lastFetchedTastePage = page
    }
    
    @MainActor
    private func tasteCategoryResults(with tastes: [String], page: Int) -> [CategoryResult] {
        var results = tasteResults
        if page > 0 {
            results.append(contentsOf: tasteResults)
        }
        
        for taste in tastes {
            let chatResult = ChatResult(title: taste, placeResponse: nil, recommendedPlaceResponse: nil)
            let categoryResult = CategoryResult(parentCategory: taste, categoricalChatResults: [chatResult])
            results.append(categoryResult)
        }
        
        return results
    }
    
    // MARK: Place Query Models
    
    @MainActor
    public func placeQueryModel(intent: AssistiveChatHostIntent) async {
        var chatResults = [ChatResult]()
        
        if let response = intent.selectedPlaceSearchResponse, let details = intent.selectedPlaceSearchDetails {
            let results = PlaceResponseFormatter.placeChatResults(
                for: intent,
                place: response,
                details: details,
                recommendedPlaceResponse: intent.selectedRecommendedPlaceSearchResponse
            )
            chatResults.append(contentsOf: results)
            if let selectedChatResult = results.first {
                selectedPlaceChatResult = selectedChatResult.id
            }
        }
        
        if !intent.placeSearchResponses.isEmpty {
            for response in intent.placeSearchResponses {
                if !response.name.isEmpty {
                    let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil, recommendedPlaceResponse: nil)
                    chatResults.append(contentsOf: results)
                }
            }
        }
        
        locationSearchText = intent.caption
        placeResults = chatResults
        recommendedPlaceQueryModel(intent: intent)
        relatedPlaceQueryModel(intent: intent)
    }
    
    @MainActor
    public func recommendedPlaceQueryModel(intent: AssistiveChatHostIntent) {
        var recommendedChatResults = [ChatResult]()
        
        if !recommendedPlaceResults.isEmpty,
           let selectedPlaceChatResult = selectedPlaceChatResult,
           let placeChatResult = placeChatResult(for: selectedPlaceChatResult),
           recommendedPlaceResults.contains(where: { $0.recommendedPlaceResponse?.fsqID == placeChatResult.recommendedPlaceResponse?.fsqID }) {
            return
        }
        
        if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
            for response in recommendedPlaceSearchResponses {
                if !response.fsqID.isEmpty {
                    if response.fsqID == intent.selectedRecommendedPlaceSearchResponse?.fsqID,
                       let placeSearchResponse = intent.selectedPlaceSearchResponse {
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeSearchResponse,
                            details: intent.selectedPlaceSearchDetails,
                            recommendedPlaceResponse: intent.selectedRecommendedPlaceSearchResponse
                        )
                        recommendedChatResults.append(contentsOf: results)
                    } else {
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
                            details: nil,
                            recommendedPlaceResponse: response
                        )
                        recommendedChatResults.append(contentsOf: results)
                    }
                }
            }
        } else if intent.recommendedPlaceSearchResponses == nil {
            for response in intent.placeSearchResponses {
                let results = PlaceResponseFormatter.placeChatResults(
                    for: intent,
                    place: response,
                    details: nil,
                    recommendedPlaceResponse: RecommendedPlaceSearchResponse(
                        fsqID: response.fsqID,
                        name: response.name,
                        categories: response.categories,
                        latitude: response.latitude,
                        longitude: response.longitude,
                        neighborhood: response.dma,
                        address: response.address,
                        country: response.country,
                        city: response.locality,
                        state: response.region,
                        postCode: response.postCode,
                        formattedAddress: response.formattedAddress,
                        photo: nil,
                        photos: [],
                        tastes: []
                    )
                )
                recommendedChatResults.append(contentsOf: results)
            }
        }
        
        recommendedPlaceResults = recommendedChatResults
    }
    
    @MainActor
    public func relatedPlaceQueryModel(intent: AssistiveChatHostIntent) {
        var relatedChatResults = [ChatResult]()
        
        guard cloudCache.hasPrivateCloudAccess else {
            relatedPlaceResults.removeAll()
            return
        }
        
        if let relatedPlaceSearchResponses = intent.relatedPlaceSearchResponses, !relatedPlaceSearchResponses.isEmpty {
            for response in relatedPlaceSearchResponses {
                if !response.fsqID.isEmpty {
                    if response.fsqID == intent.selectedRecommendedPlaceSearchResponse?.fsqID,
                       let placeSearchResponse = intent.selectedPlaceSearchResponse {
                        let results = PlaceResponseFormatter.placeChatResults(
                            for: intent,
                            place: placeSearchResponse,
                            details: intent.selectedPlaceSearchDetails,
                            recommendedPlaceResponse: intent.selectedRecommendedPlaceSearchResponse
                        )
                        relatedChatResults.append(contentsOf: results)
                    } else {
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
                            details: nil,
                            recommendedPlaceResponse: response
                        )
                        relatedChatResults.append(contentsOf: results)
                    }
                }
            }
        }
        
        relatedPlaceResults = relatedChatResults
    }
    
    @MainActor
    public func searchQueryModel(intent: AssistiveChatHostIntent) async {
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
            
            locationSearchText = intent.caption
            placeResults = newResults
            recommendedPlaceQueryModel(intent: intent)
            relatedPlaceQueryModel(intent: intent)
            return
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
                    details: detailsResponse
                )
                chatResults.append(contentsOf: results)
            }
        }
        
        for response in intent.placeSearchResponses {
            var results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
            results = results.filter { result in
                !(intent.placeDetailsResponses?.contains { $0.fsqID == result.placeResponse?.fsqID } ?? false)
            }
            chatResults.append(contentsOf: results)
        }
        
        locationSearchText = intent.caption
        placeResults = chatResults
        recommendedPlaceQueryModel(intent: intent)
        relatedPlaceQueryModel(intent: intent)
    }
    
    // MARK: Detail Intent
    
    @MainActor
    public func detailIntent(intent: AssistiveChatHostIntent) async throws {
        if intent.selectedPlaceSearchDetails == nil {
            if let placeSearchResponse = intent.selectedPlaceSearchResponse {
                intent.selectedPlaceSearchDetails = try await fetchDetails(for: [placeSearchResponse]).first
                intent.placeDetailsResponses = [intent.selectedPlaceSearchDetails!]
                if cloudCache.hasPrivateCloudAccess {
                    intent.relatedPlaceSearchResponses = try await fetchRelatedPlaces(for: placeSearchResponse.fsqID)
                }
            }
        }
    }
    
    // MARK: Autocomplete Place Model
    
    @MainActor
    public func autocompletePlaceModel(caption: String, intent: AssistiveChatHostIntent, location: CLLocation) async throws {
        if intent.caption == caption, !intent.placeSearchResponses.isEmpty {
            // Do nothing
        } else {
            let autocompleteResponse = try await placeSearchSession.autocomplete(caption: caption, parameters: intent.queryParameters, location: location)
            let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
            intent.placeSearchResponses = placeSearchResponses
        }
        
        var chatResults = [ChatResult]()
        let allResponses = intent.placeSearchResponses
        for response in allResponses {
            let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
            chatResults.append(contentsOf: results)
        }
        
        placeResults = chatResults
        recommendedPlaceQueryModel(intent: intent)
        relatedPlaceQueryModel(intent: intent)
    }
    
    //MARK: - Request Building
    private func recommendedPlaceSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async -> RecommendedPlaceSearchRequest
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

           }
           
           print("Created query for search request:\(query) near location:\(String(describing: nearLocation)) with selected chat result: \(String(describing: location))")
           if let l = location {
               ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
           } else if let locationID = selectedDestinationLocationChatResult, let l = locationChatResult(for: locationID)?.location {
               ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
           } else if nearLocation == nil, let currentLocation = locationProvider.currentLocation(){
               let l = currentLocation
               ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
               
               print("Did not find a location in the query, using current location:\(String(describing: ll))")
           }
           
           query = query.trimmingCharacters(in: .whitespacesAndNewlines)
           
           let request = RecommendedPlaceSearchRequest(query: query, ll: ll, radius: radius, categories: categories, minPrice:minPrice, maxPrice:maxPrice, openNow: openNow, nearLocation: nearLocation, limit: limit, tags:tags)
           
           return request
       }
       
       private func placeSearchRequest(intent:AssistiveChatHostIntent, location:CLLocation?) async ->PlaceSearchRequest {
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
           } else if let locationID = selectedDestinationLocationChatResult, let l = locationChatResult(for: locationID)?.location {
               ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
           } else if nearLocation == nil, let currentLocation = locationProvider.currentLocation(){
               let l = currentLocation
               ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
               
               print("Did not find a location in the query, using current location:\(String(describing: ll))")
           }
           
           query = query.trimmingCharacters(in: .whitespacesAndNewlines)
           
           let request = PlaceSearchRequest(query:query, ll: ll, radius:radius, categories: categories, fields: nil, minPrice: minPrice, maxPrice: maxPrice, openAt: openAt, openNow: openNow, nearLocation: nearLocation, sort: sort, limit:limit)
           return request
       }
}

// MARK: - Delegate Methods

extension ChatResultViewModel : @preconcurrency AssistiveChatHostMessagesDelegate {
    
    public func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?, intent: AssistiveChatHost.Intent? = nil) async throws {
        
        let checkCaption = caption
        
        let destinationChatResultID = selectedDestinationChatResultID
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let checkIntent:AssistiveChatHost.Intent = intent ?? chatHost.determineIntent(for: checkCaption, override: nil)
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            if let lastIntent = chatHost.queryIntentParameters?.queryIntents.last, lastIntent.caption == caption {
                let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, selectedRecommendedPlaceSearchResponse: lastIntent.selectedRecommendedPlaceSearchResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: destinationChatResultID, placeDetailsResponses:lastIntent.placeDetailsResponses,recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, queryParameters: queryParameters)
                
                chatHost.updateLastIntentParameters(intent:newIntent)
            } else {
                let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, selectedRecommendedPlaceSearchResponse: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID:destinationChatResultID, placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
            }
            try await chatHost.receiveMessage(caption: checkCaption, isLocalParticipant:true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
        
    }
    
    public func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID?) async throws {
        guard let chatHost = assistiveHostDelegate, let lastIntent = assistiveHostDelegate?.queryIntentParameters?.queryIntents.last, lastIntent.placeSearchResponses.count > 0 else {
            return
        }
        
        let queryParameters = try await chatHost.defaultParameters(for: placeChatResult.title)
        let newIntent = AssistiveChatHostIntent(caption: placeChatResult.title, intent: .Place, selectedPlaceSearchResponse: placeChatResult.placeResponse, selectedPlaceSearchDetails:placeChatResult.placeDetailsResponse, selectedRecommendedPlaceSearchResponse: lastIntent.selectedRecommendedPlaceSearchResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: selectedDestinationChatResultID, placeDetailsResponses: nil, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, queryParameters: queryParameters)
        
        
        guard let tappedResultPlaceResponse = placeChatResult.placeResponse else {
            chatHost.updateLastIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: newIntent.caption, isLocalParticipant: true)
            return
        }
        
        if let recommendedPlaceSearchResponses = newIntent.recommendedPlaceSearchResponses{
            for response in recommendedPlaceSearchResponses {
                if response.fsqID == tappedResultPlaceResponse.fsqID {
                    newIntent.selectedRecommendedPlaceSearchResponse = response
                }
            }
            for result in newIntent.placeSearchResponses {
                if result.fsqID == tappedResultPlaceResponse.fsqID {
                    newIntent.selectedPlaceSearchResponse = result
                }
            }
        } else {
            for result in newIntent.placeSearchResponses {
                if result.fsqID == tappedResultPlaceResponse.fsqID {
                    newIntent.selectedPlaceSearchResponse = result
                }
            }
        }
        
        try await self.detailIntent(intent: newIntent)
        
        chatHost.updateLastIntentParameters(intent: newIntent)
        
        if let queryIntentParameters = chatHost.queryIntentParameters {
            try await didUpdateQuery(with: queryIntentParameters)
        }
    }
    
    @MainActor
    public func didTapMarker(with fsqId:String?) async throws {
        guard let fsqId = fsqId else {
            return
        }
        
        if let placeChatResult = placeChatResult(for:fsqId) {
            selectedPlaceChatResult = placeChatResult.id
        }
    }
    
    @MainActor
    public func didTap(placeChatResult: ChatResult) async throws {
        guard let lastIntent = assistiveHostDelegate?.queryIntentParameters?.queryIntents.last, lastIntent.placeSearchResponses.count > 0 else {
            return
        }
        
        if lastIntent.intent == .Place, let currentlySelectedPlaceSearchResponse = lastIntent.selectedPlaceSearchResponse, currentlySelectedPlaceSearchResponse.fsqID == placeChatResult.placeResponse?.fsqID, lastIntent.selectedPlaceSearchDetails != nil {
            return
        }
        
        if selectedDestinationLocationChatResult == nil {
            selectedDestinationLocationChatResult = lastIntent.selectedDestinationLocationID
        }
        
        if selectedSourceLocationChatResult == nil {
            selectedSourceLocationChatResult = selectedDestinationLocationChatResult
        }
        
        try await updateLastIntentParameter(for: placeChatResult, selectedDestinationChatResultID:selectedDestinationLocationChatResult)
        
    }
    
    @MainActor
    public func didTap(locationChatResult: LocationResult) async throws {
        guard let chatHost = assistiveHostDelegate else {
            return
        }
        
        let queryParameters = try await chatHost.defaultParameters(for: locationChatResult.locationName)
        
        if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult {
            let newIntent = AssistiveChatHostIntent(caption: locationChatResult.locationName, intent:.Location, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, selectedRecommendedPlaceSearchResponse: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            chatHost.appendIntentParameters(intent: newIntent)
        } else {
            selectedDestinationLocationChatResult = locationChatResult.id
            let newIntent = AssistiveChatHostIntent(caption: locationChatResult.locationName, intent:.Location, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, selectedRecommendedPlaceSearchResponse:  nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: locationChatResult.id, placeDetailsResponses:nil, queryParameters: queryParameters)
            
            chatHost.appendIntentParameters(intent: newIntent)
        }
        
        try await chatHost.receiveMessage(caption: locationChatResult.locationName, isLocalParticipant:true)
    }
    
    @MainActor
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?,
                       selectedDestinationChatResultID:UUID?, intent:AssistiveChatHost.Intent = .Search) async {
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let caption = chatResult.title
            
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            
            let placeSearchResponses = chatResult.placeResponse != nil ? [chatResult.placeResponse!] : [PlaceSearchResponse]()
            let destinationLocationChatResult = selectedDestinationChatResultID
            
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: selectedPlaceSearchResponse, selectedPlaceSearchDetails: selectedPlaceSearchDetails, selectedRecommendedPlaceSearchResponse: selectedRecommendedPlaceSearchResponse, placeSearchResponses: placeSearchResponses, selectedDestinationLocationID: destinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: chatResult.title, isLocalParticipant: true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
    }
    
    @MainActor
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
            if let destinationChatResult = selectedDestinationChatResult, let _ = locationChatResult(for: destinationChatResult) {
                
            } else if let lastIntent = assistiveHostDelegate?.queryIntentParameters?.queryIntents.last  {
                let locationChatResult = locationChatResult(for: lastIntent.selectedDestinationLocationID ?? currentLocationResult.id)
                selectedDestinationChatResult = locationChatResult?.id
                selectedDestinationLocationChatResult = locationChatResult?.id
            } else {
                throw ChatResultViewModelError.missingSelectedDestinationLocationChatResult
            }
        }
        
        if let lastIntent = queryParametersHistory.last?.queryIntents.last, lastIntent.intent != .Location {
            let locationChatResult =  locationChatResult(for: selectedDestinationChatResult ?? currentLocationResult.id)
            
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            try await searchIntent(intent: lastIntent, location: locationChatResult?.location)
            try await didUpdateQuery(with: parameters)
        } else if let lastIntent = queryParametersHistory.last?.queryIntents.last, lastIntent.intent == .Location {
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            try await searchIntent(intent: lastIntent, location: nil)
            try await didUpdateQuery(with: parameters)
        } else {
            do {
                guard let chatHost = self.assistiveHostDelegate else {
                    return
                }
                
                let intent:AssistiveChatHost.Intent = chatHost.determineIntent(for: caption, override: nil)
                let queryParameters = try await chatHost.defaultParameters(for: caption)
                let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, selectedRecommendedPlaceSearchResponse: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
                try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
                try await searchIntent(intent: newIntent, location: locationChatResult(with:caption).location! )
                try await didUpdateQuery(with: parameters)
            } catch {
                analytics?.track(name: "error \(error)")
                print(error)
            }
        }
    }
    
    @MainActor
    public func didUpdateQuery(with parameters: AssistiveChatHostQueryParameters) async throws {
        try await refreshModel(queryIntents: parameters.queryIntents)
    }
    
    @MainActor
    public func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters) {
        queryParametersHistory.append(parameters)
    }
}

extension ChatResultViewModel : AssistiveChatHostStreamResponseDelegate {
    public func didReceiveStreamingResult(with string: String, for result: ChatResult, promptTokens: Int, completionTokens: Int) async {
        await didReceiveStreamingResult(with: string, for: result)
        if promptTokens > 0 || completionTokens > 0 {
            analytics?.track(name: "usingGeneratedGPTDescription", properties: ["promptTokens":promptTokens, "completionTokens":completionTokens])
        }
    }
    
    @MainActor
    public func willReceiveStreamingResult(for chatResultID: ChatResult.ID) async {
        fetchingPlaceID = chatResultID
        isFetchingPlaceDescription = true
    }
    
    @MainActor
    public func didFinishStreamingResult() async {
        if let fetchingPlaceID = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: fetchingPlaceID), let fsqid = placeChatResult.placeDetailsResponse?.fsqID, let description = placeChatResult.placeDetailsResponse?.description {
            assistiveHostDelegate?.cloudCache.storeGeneratedDescription(for: fsqid, description:description)
        }
        
        fetchingPlaceID = nil
        isFetchingPlaceDescription = false
    }
    
    @MainActor
    private func didReceiveStreamingResult(with string: String, for result: ChatResult) async {
        let candidates = placeResults.filter { checkResult in
            return checkResult.placeResponse?.fsqID != nil && checkResult.placeResponse?.fsqID == result.placeResponse?.fsqID
        }
        
        guard let firstCandidate = candidates.first else {
            return
        }
        
        var selectedId:ChatResult.ID = firstCandidate.id
        
        if let placeDetailsResponse = firstCandidate.placeDetailsResponse {
            let newDetailsResponse = PlaceDetailsResponse(searchResponse: placeDetailsResponse.searchResponse, photoResponses: placeDetailsResponse.photoResponses, tipsResponses: placeDetailsResponse.tipsResponses, description: (placeDetailsResponse.description ?? "").appending(string), tel: placeDetailsResponse.tel, fax: placeDetailsResponse.fax, email: placeDetailsResponse.email, website: placeDetailsResponse.website, socialMedia: placeDetailsResponse.socialMedia, verified: placeDetailsResponse.verified, hours: placeDetailsResponse.hours, openNow: placeDetailsResponse.openNow, hoursPopular:placeDetailsResponse.hoursPopular, rating: placeDetailsResponse.rating, stats: placeDetailsResponse.stats, popularity: placeDetailsResponse.popularity, price: placeDetailsResponse.price, menu: placeDetailsResponse.menu, dateClosed: placeDetailsResponse.dateClosed, tastes: placeDetailsResponse.tastes, features: placeDetailsResponse.features)
            
            var newPlaceResults = [ChatResult]()
            let fsqID = newDetailsResponse.fsqID
            for placeResult in placeResults {
                if placeResult.placeResponse?.fsqID == fsqID {
                    let newPlaceResult = ChatResult(title: placeResult.title, placeResponse: placeResult.placeResponse, recommendedPlaceResponse: nil, placeDetailsResponse: newDetailsResponse)
                    newPlaceResults.append(newPlaceResult)
                    selectedId = newPlaceResult.id
                } else {
                    newPlaceResults.append(placeResult)
                }
            }
            
            
            placeResults = newPlaceResults
            selectedPlaceChatResult = selectedId
        }
    }
}
