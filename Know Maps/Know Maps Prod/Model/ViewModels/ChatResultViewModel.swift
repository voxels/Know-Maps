//
//  ChatResultViewModel.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation
import Segment

enum ChatResultViewModelError : Error {
    case MissingLastIntent
    case MissingSelectedPlaceSearchResponse
    case MissingSelectedPlaceDetailsResponse
    case NoAutocompleteResultsFound
    case MissingCurrentLocation
    case MissingSelectedDestinationLocationChatResult
    case RetryTimeout
}

public class ChatResultViewModel : ObservableObject {
    public weak var delegate:ChatResultViewModelDelegate?
    public weak var assistiveHostDelegate:AssistiveChatHostDelegate?
    private let placeSearchSession:PlaceSearchSession = PlaceSearchSession()
    private let personalizedSearchSession:PersonalizedSearchSession
    public var locationProvider:LocationProvider
    public var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    public var fetchingPlaceID:ChatResult.ID?
    public var analytics:Analytics?
    
    public var cloudCache:CloudCache
    public var featureFlags:FeatureFlags
    public var cachedLocationRecords:[UserCachedRecord]?
    public var cachedTasteRecords:[UserCachedRecord]?
    public var cachedCategoryRecords:[UserCachedRecord]?
    public var cachedPlaceRecords:[UserCachedRecord]?
    public var cachedListRecords:[UserCachedRecord] = [UserCachedRecord]()
    @Published public var isRefreshingCache:Bool = false
    @Published public var cachedCategoryResults = [CategoryResult]()
    @Published public var cachedTasteResults = [CategoryResult]()
    @Published public var cachedPlaceResults = [CategoryResult]()
    @Published public var cachedListResults = [CategoryResult]()
    @Published public var allCachedResults = [CategoryResult]()
    @Published public var cachedLocationResults = [LocationResult]()
    @Published public var selectedCategoryResult:CategoryResult.ID?
    @Published public var selectedSavedResult:CategoryResult.ID?
    @Published public var selectedTasteCategoryResult:CategoryResult.ID?
    @Published public var selectedListCategoryResult:CategoryResult.ID?
    @Published public var selectedCategoryChatResult:ChatResult.ID?
    @Published public var selectedPlaceChatResult:ChatResult.ID?
    @Published public var selectedSourceLocationChatResult:LocationResult.ID?
    @Published public var selectedDestinationLocationChatResult:LocationResult.ID?
    @Published var isFetchingPlaceDescription:Bool = false
    @Published public var locationSearchText: String = ""
    @Published public var categoryResults:[CategoryResult] = [CategoryResult]()
    @Published public var tasteResults:[CategoryResult] = [CategoryResult]()
    @Published public var searchCategoryResults:[CategoryResult] = [CategoryResult]()
    @Published public var placeResults:[ChatResult] = [ChatResult]()
    @Published public var recommendedPlaceResults:[ChatResult] = [ChatResult]()
    @Published public var relatedPlaceResults:[ChatResult] = [ChatResult]()
    @Published public var locationResults:[LocationResult] = [LocationResult]()
    @Published public var currentLocationResult = LocationResult(locationName: "Current Location", location: nil)
    
    public var lastFetchedTastePage:Int = 0
    public var sessionRetryCount = 0
    
    public func refreshSessions() async throws {
        if sessionRetryCount == 0 {
            sessionRetryCount += 1
            try await placeSearchSession.invalidateSession()
            sessionRetryCount = 0
        } else {
            throw ChatResultViewModelError.RetryTimeout
        }
    }
    
    public func currentLocationName() async throws -> String? {
        if let location = locationProvider.currentLocation() {
            return try await assistiveHostDelegate?.languageDelegate.lookUpLocation(location: location)?.first?.name ?? "Current Location"
        }
        return nil
    }
    
    public var filteredRecommendedPlaceResults:[ChatResult] {
        get {
            var retval = recommendedPlaceResults

            if let selectedSourceLocationChatResult = selectedSourceLocationChatResult, let locationChatResult = locationChatResult(for: selectedSourceLocationChatResult), let location = locationChatResult.location {
                retval.sort { result, checkResult in
                    guard let placeResponse = result.placeResponse, let checkPlaceResponse = checkResult.placeResponse else {
                        return false
                    }
                    let resultLocation = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                    let checkResultLocation = CLLocation(latitude: checkPlaceResponse.latitude, longitude: checkPlaceResponse.longitude)
                    return resultLocation.distance(from: location) < checkResultLocation.distance(from: location)
                }
            }
        
            return retval
        }
    }
    
    public var filteredLocationResults:[LocationResult] {
        if !cachedLocationResults.isEmpty {
            var results = Set<LocationResult>()
            
            for cachedLocationResult in cachedLocationResults {
                results.insert(cachedLocationResult)
            }
            
            for result in locationResults {
                if !results.contains (where: { checkResult in
                    result.locationName == checkResult.locationName
                }) {
                    results.insert(result)
                }
            }
            
            var allLocationResults = Array(results).sorted { firstResult, secondResult in
                return firstResult.locationName <= secondResult.locationName
            }
                        
            if currentLocationResult.location != nil, !allLocationResults.contains(currentLocationResult) {
                allLocationResults.insert(currentLocationResult, at:0)
            } else if currentLocationResult.location != nil {
                allLocationResults.removeAll { result in
                    result.id == currentLocationResult.id
                }
                allLocationResults.insert(currentLocationResult, at:0)
            }
            return allLocationResults
        } else {
            var allLocationResults = locationResults.sorted { firstResult, secondResult in
                return firstResult.locationName <= secondResult.locationName
            }
                        
            if currentLocationResult.location != nil, !allLocationResults.contains(currentLocationResult) {
                allLocationResults.insert(currentLocationResult, at:0)
            } else if currentLocationResult.location != nil {
                allLocationResults.removeAll { result in
                    result.id == currentLocationResult.id
                }
                allLocationResults.insert(currentLocationResult, at:0)
            }
            return allLocationResults
        }
    }
    
    public var filteredSourceLocationResults:[LocationResult] {
        return filteredLocationResults
    }
    
    public var filteredDestinationLocationResults:[LocationResult] {
        return filteredLocationResults
    }
    
    public var filteredResults:[CategoryResult] {
        get {
            return categoryResults.filter { result in
                result.categoricalChatResults != nil
            }
        }
    }
    
    public var filteredPlaceResults:[ChatResult] {
        get {
            var retval = placeResults.sorted { result, checkResult in
                return result.title <= checkResult.title
            }

            if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationChatResult = locationChatResult(for: selectedDestinationLocationChatResult), let location = locationChatResult.location {
                retval.sort { result, checkResult in
                    guard let placeResponse = result.placeResponse, let checkPlaceResponse = checkResult.placeResponse else {
                        return false
                    }
                    let resultLocation = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                    let checkResultLocation = CLLocation(latitude: checkPlaceResponse.latitude, longitude: checkPlaceResponse.longitude)
                    return resultLocation.distance(from: location) < checkResultLocation.distance(from: location)
                }
            }
        
            return retval
        }
    }
    
    public init(delegate: ChatResultViewModelDelegate? = nil, assistiveHostDelegate: AssistiveChatHostDelegate? = nil, locationProvider: LocationProvider, queryParametersHistory: [AssistiveChatHostQueryParameters] = [AssistiveChatHostQueryParameters](), fetchingPlaceID: ChatResult.ID? = nil, analytics: Analytics? = nil, cloudCache:CloudCache, featureFlags:FeatureFlags, selectedCategoryChatResult: ChatResult.ID? = nil, selectedPlaceChatResult: ChatResult.ID? = nil,  selectedSourceLocationChatResult: LocationResult.ID? = nil, selectedDestinationLocationChatResult: LocationResult.ID? = nil, isFetchingPlaceDescription: Bool = false, locationSearchText: String = "", categoryResults: [CategoryResult] = [CategoryResult](), searchCategoryResults:[CategoryResult] = [CategoryResult](), locationResults: [LocationResult] = [LocationResult]()) {
        self.delegate = delegate
        self.assistiveHostDelegate = assistiveHostDelegate
        self.locationProvider = locationProvider
        self.queryParametersHistory = queryParametersHistory
        self.fetchingPlaceID = fetchingPlaceID
        self.analytics = analytics
        self.cloudCache = cloudCache
        self.featureFlags = featureFlags
        self.selectedCategoryChatResult = selectedCategoryChatResult
        self.selectedPlaceChatResult = selectedPlaceChatResult
        self.selectedSourceLocationChatResult = selectedSourceLocationChatResult
        self.selectedDestinationLocationChatResult = selectedDestinationLocationChatResult
        self.isFetchingPlaceDescription = isFetchingPlaceDescription
        self.locationSearchText = locationSearchText
        self.categoryResults = categoryResults
        self.searchCategoryResults = searchCategoryResults
        self.locationResults = locationResults
        self.personalizedSearchSession = PersonalizedSearchSession(cloudCache: cloudCache)
        self.placeResults = placeResults
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
    
    @MainActor
    public func resetPlaceModel() {
        selectedPlaceChatResult = nil
        placeResults.removeAll()
        recommendedPlaceResults.removeAll()
        relatedPlaceResults.removeAll()

        analytics?.track(name: "resetPlaceModel")
    }
    
    @MainActor
    public func autocompleteTastes(lastIntent:AssistiveChatHostIntent, location:CLLocation) async throws {
        let query = lastIntent.caption
        let rawResponse = try await personalizedSearchSession.autocompleteTastes(caption: query, parameters:lastIntent.queryParameters, location: location)
        let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: rawResponse)
        tasteResults = tasteCategoryResults(with: tastes.map(\.self.text), page:0)
        lastFetchedTastePage = 0
        try await refreshCachedTastes(cloudCache: cloudCache)
    }
    
    @MainActor
    public func refreshTastes(page:Int) async throws {
        if page > lastFetchedTastePage || tasteResults.isEmpty {
            let tastes = try await personalizedSearchSession.fetchTastes(page:page)
            tasteResults = tasteCategoryResults(with: tastes, page:page)
            lastFetchedTastePage = page
            try await refreshCachedTastes(cloudCache: cloudCache)
        } else {
            refreshTasteCategories(page: page)
            try await refreshCachedTastes(cloudCache: cloudCache)
        }
    }
    
    @MainActor
    public func refreshTasteCategories(page:Int) {
        let tastes = tasteResults.map { result in
            result.parentCategory
        }
        
        tasteResults = tasteCategoryResults(with: tastes, page:page)
        lastFetchedTastePage = page
    }
    
    @MainActor
    public func refreshCache(cloudCache:CloudCache) async throws {        
        isRefreshingCache = true
        do {
            try await refreshCachedCategories(cloudCache: cloudCache)
        } catch {
            print(error)
            analytics?.track(name: "error \(error)")
        }
        do {
            try await refreshCachedTastes(cloudCache: cloudCache)
        } catch {
            print(error)
            analytics?.track(name: "error \(error)")
        }
        
        do {
            try await refreshCachedLists(cloudCache: cloudCache)
        } catch {
            print(error)
            analytics?.track(name: "error \(error)")
        }
        refreshCachedResults()
        isRefreshingCache = false
    }
    
    @MainActor
    public func refreshCachedLocations(cloudCache:CloudCache) async throws {
        
        let storedLocationRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Location")
        
        guard !storedLocationRecords.isEmpty else {
            return
        }
        
        cachedLocationRecords = storedLocationRecords
        cachedLocationResults = savedLocationResults()
    }
    
    @MainActor
    public func refreshCachedCategories(cloudCache:CloudCache) async throws {
        
        let storedCategoryRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Category")
        
        guard !storedCategoryRecords.isEmpty else {
            return
        }
        
        cachedCategoryRecords = storedCategoryRecords
        cachedCategoryResults = savedCategoricalResults()
    }
    
    @MainActor
    public func refreshCachedTastes(cloudCache:CloudCache) async throws {
        let storedTasteRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Taste")
        
        guard !storedTasteRecords.isEmpty else {
            return
        }
        
        cachedTasteRecords = storedTasteRecords
        cachedTasteResults = savedTasteResults()
    }
    
    @MainActor
    public func refreshCachedLists(cloudCache:CloudCache) async throws {
        let storedPlaceRecords =  try await cloudCache.fetchGroupedUserCachedRecords(for: "Place")
        let storedListRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "List")
        
        guard !storedListRecords.isEmpty else {
            return
        }
        
        cachedPlaceRecords = storedPlaceRecords
        cachedPlaceResults = savedPlaceResults()
        cachedListRecords = storedListRecords
        cachedListResults = savedListResults()
    }
    
    @MainActor
    public func refreshCachedResults() {
        allCachedResults = allSavedResults()
    }
    
    @MainActor
    public func appendCachedLocation(with record:UserCachedRecord) {
        cachedLocationRecords?.append(record)
        cachedLocationResults = savedLocationResults()
    }
    
    @MainActor
    public func appendCachedCategory(with record:UserCachedRecord) {
        cachedCategoryRecords?.append(record)
        cachedCategoryResults = savedCategoricalResults()
    }
    
    @MainActor
    public func appendCachedTaste(with record:UserCachedRecord) {
        cachedTasteRecords?.append(record)
        cachedTasteResults = savedTasteResults()
    }
    
    @MainActor
    public func appendCachedList(with record:UserCachedRecord) {
        cachedListRecords.append(record)
        cachedListResults = savedListResults()
    }

    @MainActor
    public func appendCachedPlace(with record:UserCachedRecord) {
        cachedPlaceRecords?.append(record)
        cachedPlaceResults = savedListResults()
    }
    
    public func cachedCategories(contains category:String)->Bool {
        guard let cachedRecords = cachedCategoryRecords, !cachedRecords.isEmpty else {
            return false
        }
        
        return cachedRecords.contains { record in
            record.identity == category
        }
    }
    
    public func cachedTastes(contains taste:String)->Bool {
        guard let cachedRecords = cachedTasteRecords, !cachedRecords.isEmpty else {
            return false
        }
        
        return cachedRecords.contains { record in
            record.identity == taste
        }
    }
    
    public func cachedLocation(contains location:String)->Bool {
        guard let cachedLocationRecords = cachedLocationRecords, !cachedLocationRecords.isEmpty else {
            return false
        }
        return cachedLocationRecords.contains { record in
            record.identity == location
        }
    }
    
    public func cachedLocationIdentity(for location:CLLocation)->String{
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }
    
    public func locationChatResult(for selectedChatResultID:LocationResult.ID)->LocationResult?{
        var selectedResult = cachedLocationResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
                                                         
         if let selectedResult = selectedResult {
             return selectedResult
         }

        selectedResult = locationResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        if let selectedResult = selectedResult {
            return selectedResult
        }
        
        let savedResult = filteredLocationResults.first(where: {checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        return savedResult
    }
    
    public func locationChatResult(with title:String)->LocationResult {
        let selectedResult = locationResults.first { checkResult in
            checkResult.locationName == title
        }
        
        if let selectedResult = selectedResult {
            return selectedResult
        }
        
        let savedResult = filteredLocationResults.first { checkResult in
            checkResult.locationName == title
        }
        
        if let savedResult = savedResult {
            return savedResult
        }
        
        return LocationResult(locationName: title)
    }
    
    public func placeChatResult(for selectedChatResultID:ChatResult.ID)->ChatResult?{
        var checkChatResultID = selectedChatResultID

        if cloudCache.hasPrivateCloudAccess{
            let recommendedResult = recommendedPlaceResults.first(where: { checkResult in
                return checkResult.id == checkChatResultID
            })
            
            if let recommendedResult = recommendedResult {
                let selectedResult = placeResults.first(where: { checkResult in
                    return checkResult.placeResponse?.fsqID == recommendedResult.placeResponse?.fsqID
                })
                
                if let selectedResult = selectedResult {
                    checkChatResultID = selectedResult.id
                }
                
                return selectedResult
            }
        }
        
        let selectedResult = placeResults.first(where: { checkResult in
            return checkResult.id == checkChatResultID
        })
        
        return selectedResult
    }
    
    public func placeChatResult(for selectedPlaceFsqID:String)->ChatResult? {
        
        if cloudCache.hasPrivateCloudAccess{
            let recommendedResult = recommendedPlaceResults.first(where: { checkResult in
                return checkResult.placeResponse?.fsqID == selectedPlaceFsqID
            })
            
            if let recommendedResult = recommendedResult {
                return recommendedResult
            }
            
            let relatedResult = relatedPlaceResults.first(where: { checkResult in
                return checkResult.placeResponse?.fsqID == selectedPlaceFsqID
            })
            
            if let relatedResult = relatedResult {
                return relatedResult
            }
        }
        
        let selectedResult = placeResults.first(where: { checkResult in
            return checkResult.placeResponse?.fsqID == selectedPlaceFsqID
        })
        
        return selectedResult
    }
    
    
    
    public func cachedChatResult(for selectedCategoryID:CategoryResult.ID)->ChatResult? {
        let searchCategories = allCachedResults
        
        var parentCategory = searchCategories.first { result in
            return result.id == selectedCategoryID
        }
        
        if parentCategory == nil {
            var allChildrenCategories = [CategoryResult]()
            for searchCategory in searchCategories {
                if let children = searchCategory.children {
                    for childCategory in children {
                        allChildrenCategories.append(childCategory)
                    }
                }
            }
            
            parentCategory = allChildrenCategories.first { result in
                return result.id == selectedCategoryID
            }
        }
        
        guard let parentCategory = parentCategory else {
            return nil
        }
        
        if parentCategory.id == selectedCategoryID, parentCategory.categoricalChatResults?.count == 1, let child = parentCategory.categoricalChatResults?.first, child.title == parentCategory.parentCategory {
            return parentCategory.categoricalChatResults?.first
        }
        
        if let children = parentCategory.children {
            for child in children {
                if child.id == selectedCategoryID {
                    return child.categoricalChatResults?.first
                }
            }
        }
        
        return nil
    }
    
    public func tasteResult(for selectedCategoryID:CategoryResult.ID)->ChatResult? {
        let searchCategories = tasteResults
        
        let parentCategory = searchCategories.first { result in
            return result.id == selectedCategoryID
        }
        
        guard let parentCategory = parentCategory else {
            return nil
        }
        
        if parentCategory.id == selectedCategoryID {
            return parentCategory.categoricalChatResults?.first
        }
        
        
        return nil
    }
    
    public func cachedListResult(for selectedCategoryID:CategoryResult.ID)->CategoryResult? {
        let searchCategories = cachedListResults
        let parentCategory = searchCategories.first { result in
            return result.id == selectedCategoryID
        }
        
        return parentCategory
    }
    
    public func categoricalResult(for selectedCategoryID:CategoryResult.ID)->ChatResult? {
        var searchCategories = [CategoryResult]()
        for result in categoryResults {
            searchCategories.append(result)
            if let children = result.children {
                for child in children {
                    searchCategories.append(child)
                }
            }
        }
        
        
        let parentCategory = searchCategories.first { result in
            if let children = result.children {
                var foundChild = false
                for child in children {
                    if child.id == selectedCategoryID {
                        print("found match:\(child.id)")
                        foundChild = true
                    }
                }
                if !foundChild {
                    return result.id == selectedCategoryID
                }
            } else {
                return result.id == selectedCategoryID
            }
            return false
        }
        
        guard let parentCategory = parentCategory else {
            return nil
        }
        
        if parentCategory.id == selectedCategoryID {
            return parentCategory.categoricalChatResults?.last
        }
        
        if let children = parentCategory.children {
            for child in children {
                if child.id == selectedCategoryID {
                    return child.categoricalChatResults?.first
                }
            }
        }
        
        return nil
    }
    
    public func chatResult(title:String)->ChatResult? {
        return categoryResults.compactMap { categoryResult in
            return categoryResult.result(title: title)
        }.first
    }
    
    public func chatResult(for selectedChatResultID:ChatResult.ID)->ChatResult?{
        let allResults = categoryResults.compactMap({ categoryResult in
            return categoryResult.categoricalChatResults
        })
        
        var foundResult:ChatResult?
        for allResult in allResults {
            for result in allResult {
                if result.id == selectedChatResultID || result.parentId == selectedChatResultID {
                    foundResult = result
                }
            }
        }
        
        if foundResult == nil {
            return chatResult(title: locationSearchText)
        }
        
        return foundResult
    }
    
    
    public func checkSearchTextForLocations(with text:String) async throws ->[CLPlacemark]? {
        let tags = try assistiveHostDelegate?.tags(for: text)
        return try await assistiveHostDelegate?.nearLocationCoordinate(for: text, tags:tags)
    }
    
    @MainActor
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        guard let chatHost = self.assistiveHostDelegate else {
            return
        }
        
        let placemarks = try? await checkSearchTextForLocations(with: caption)
        
        if let placemarks = placemarks, let firstPlacemark = placemarks.first, let _ = firstPlacemark.location {
                queryParametersHistory.append(parameters)
                let locations = placemarks.compactMap({ placemark in
                    return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                })
                var existingLocationNames = locationResults.map { $0.locationName }
                let newLocations = locations.filter { result in
                    !existingLocationNames.contains(result.locationName)
                }
                
                locationResults.append(contentsOf:newLocations )
                
                existingLocationNames = locationResults.map { $0.locationName }
                
                analytics?.track(name: "foundPlacemarksInQuery")
            }
        
        if let sourceLocationID = selectedSourceLocationChatResult, let sourceLocationResult = locationChatResult(for: sourceLocationID), let queryLocation = sourceLocationResult.location, let queryPlacemarks = try await chatHost.languageDelegate.lookUpLocation(location: queryLocation) {
            
            let existingLocationNames = locationResults.compactMap { result in
                return result.locationName
            }
            
            for queryPlacemark in queryPlacemarks {
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
        
        
        if let sourceLocationID = selectedDestinationLocationChatResult, let sourceLocationResult = locationChatResult(for: sourceLocationID), let queryLocation = sourceLocationResult.location, let destinationPlacemarks = try await chatHost.languageDelegate.lookUpLocation(location: queryLocation) {
            
            let existingLocationNames = locationResults.compactMap { result in
                return result.locationName
            }
            
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
        
        if let sourceLocationID = selectedDestinationLocationChatResult, let sourceLocationResult = locationChatResult(for: sourceLocationID), sourceLocationResult.location == nil, let destinationPlacemarks = try await chatHost.languageDelegate.lookUpLocationName(name: sourceLocationResult.locationName) {
            
            let existingLocationNames = locationResults.compactMap { result in
                return result.locationName
            }
            
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
            
            selectedDestinationLocationChatResult = locationResults.first(where: { $0.locationName == sourceLocationResult.locationName })?.id
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
            if cloudCache.hasPrivateCloudAccess, let location = location {
                let autocompleteResponse = try await personalizedSearchSession.autocompleteTastes(caption: intent.caption, parameters: intent.queryParameters, location: location)
                let tastes = try PlaceResponseFormatter.autocompleteTastesResponses(with: autocompleteResponse)
                intent.tasteAutocompleteResponese = tastes
                analytics?.track(name: "searchIntentWithPersonalizedAutocompleteTastes")
            }
        }
    }
    
    @MainActor
    public func detailIntent( intent: AssistiveChatHostIntent) async throws {
        if intent.selectedPlaceSearchDetails == nil {
            if intent.placeSearchResponses.count > 0, let placeSearchResponse = intent.selectedPlaceSearchResponse {
                intent.selectedPlaceSearchDetails = try await fetchDetails(for: [placeSearchResponse]).first
                intent.placeDetailsResponses = [intent.selectedPlaceSearchDetails!]
                if cloudCache.hasPrivateCloudAccess {
                    intent.relatedPlaceSearchResponses = try await fetchRelatedPlaces(for: placeSearchResponse.fsqID)
                }
            }
        } else {

        }
    }
    
    @MainActor
    public func autocompletePlaceModel(caption:String, intent: AssistiveChatHostIntent, location:CLLocation) async throws {
        
        if intent.caption == caption, !intent.placeSearchResponses.isEmpty {
            // Do nothing
        } else {
                let autocompleteResponse = try await placeSearchSession.autocomplete(caption: caption, parameters: intent.queryParameters, location: location)
                let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
                intent.placeSearchResponses = placeSearchResponses
        }
        
            
            var chatResults = [ChatResult]()
            let allResponses = intent.placeSearchResponses
            for index in 0..<allResponses.count {
                let response = allResponses[index]
                
                let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
                chatResults.append(contentsOf:results)
            }
            
            placeResults = chatResults
            recommendedPlaceQueryModel(intent: intent)
            relatedPlaceQueryModel(intent: intent)
    }
    
    @MainActor
    public func
    refreshModel(queryIntents:[AssistiveChatHostIntent]? = nil) async throws {
        guard let chatHost = self.assistiveHostDelegate else {
            return
        }
        
        var caption = ""
        
        if let lastIntent = queryIntents?.last {
            caption = lastIntent.caption
            
            if let selectedPlaceChatResult = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: selectedPlaceChatResult) {
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
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, selectedRecommendedPlaceSearchResponse: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID:location?.selectedDestinationLocationID ?? filteredLocationResults.first!.id , placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await model(intent: newIntent)
        }
        
        if let placemarks = try await checkSearchTextForLocations(with: caption) {
            let locations = placemarks.compactMap({ placemark in
                return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
            })
            let existingLocationNames = locationResults.map { $0.locationName }
            let newLocations = locations.filter { result in
                !existingLocationNames.contains(result.locationName)
            }
            
            locationResults.append(contentsOf:newLocations )
        }
        
        if let sourceLocationID = selectedSourceLocationChatResult, let sourceLocationResult = locationChatResult(for: sourceLocationID), let queryLocation = sourceLocationResult.location, let queryPlacemarks = try await chatHost.languageDelegate.lookUpLocation(location: queryLocation) {
            
            let existingLocationNames = locationResults.compactMap { result in
                return result.locationName
            }
            
            for queryPlacemark in queryPlacemarks {
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
        
        
        if let sourceLocationID = selectedDestinationLocationChatResult, let sourceLocationResult = locationChatResult(for: sourceLocationID), let queryLocation = sourceLocationResult.location, let destinationPlacemarks = try await chatHost.languageDelegate.lookUpLocation(location: queryLocation) {
            
            let existingLocationNames = locationResults.compactMap { result in
                return result.locationName
            }
            
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
    }
    
    public func model(intent:AssistiveChatHostIntent) async throws {
        switch intent.intent {
        case .Place:
            await placeQueryModel(intent: intent)
            analytics?.track(name: "modelPlaceQueryBuilt")
        case .Search:
            await searchQueryModel(intent: intent)
            try await detailIntent(intent: intent)
            analytics?.track(name: "modelSearchQueryBuilt")
        case .Location:
            fallthrough
        case .AutocompleteSearch:
            do {
                if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationResult = locationChatResult(for: selectedDestinationLocationChatResult), let finalLocation = locationResult.location {
                    try await autocompletePlaceModel(caption: intent.caption, intent: intent, location: finalLocation)
                    analytics?.track(name: "modelAutocompletePlaceModelBuilt")
                }
            } catch {
                analytics?.track(name: "error \(error)")
                print(error)
            }
        case .AutocompleteTastes:
            do {
                if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationResult = locationChatResult(for: selectedDestinationLocationChatResult), let finalLocation = locationResult.location {
                    try await autocompleteTastes(lastIntent: intent, location: finalLocation)
                    analytics?.track(name: "modelAutocompletePlaceModelBuilt")
                }
            }
        }
    }
    
    @MainActor
    public func placeQueryModel(intent:AssistiveChatHostIntent) async {
        var chatResults = [ChatResult]()

        if let response = intent.selectedPlaceSearchResponse, let details = intent.selectedPlaceSearchDetails {
            let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: details, recommendedPlaceResponse: intent.selectedRecommendedPlaceSearchResponse)
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
    public func recommendedPlaceQueryModel(intent:AssistiveChatHostIntent) {
        var recommendedChatResults = [ChatResult]()
                
        if !recommendedPlaceResults.isEmpty, let selectedPlaceChatResult = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: selectedPlaceChatResult), recommendedPlaceResults.contains(where: { result in
            result.recommendedPlaceResponse?.fsqID == placeChatResult.recommendedPlaceResponse?.fsqID
        }){
            return
        }
        
        if let recommendedPlaceSearchResponses = intent.recommendedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
            for response in recommendedPlaceSearchResponses {
                if !response.fsqID.isEmpty {
                    if response.fsqID == intent.selectedRecommendedPlaceSearchResponse?.fsqID, let placeSearchResponse = intent.selectedPlaceSearchResponse {
                        let results = PlaceResponseFormatter.placeChatResults(for: intent, place: placeSearchResponse, details: intent.selectedPlaceSearchDetails, recommendedPlaceResponse: intent.selectedRecommendedPlaceSearchResponse)
                        recommendedChatResults.append(contentsOf: results)
                    } else {
                        let results = PlaceResponseFormatter.placeChatResults(for: intent, place: PlaceSearchResponse(fsqID: response.fsqID, name: response.name, categories: response.categories, latitude: response.latitude, longitude: response.longitude, address: response.address, addressExtended: response.formattedAddress, country: response.country, dma: response.neighborhood, formattedAddress: response.formattedAddress, locality: response.city, postCode: response.postCode, region: response.state, chains: [], link: "", childIDs: [], parentIDs: []), details: nil, recommendedPlaceResponse: response)
                        recommendedChatResults.append(contentsOf: results)
                    }
                }
            }
        } else if intent.recommendedPlaceSearchResponses == nil {
            for response in intent.placeSearchResponses {
                let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil, recommendedPlaceResponse: RecommendedPlaceSearchResponse(fsqID: response.fsqID, name: response.name, categories: response.categories, latitude: response.latitude, longitude: response.longitude, neighborhood: response.dma, address: response.address, country: response.country, city: "", state: response.region, postCode: response.postCode, formattedAddress: response.formattedAddress, photo: nil, photos: [], tastes: []))
                recommendedChatResults.append(contentsOf: results)
            }
        }
        
        recommendedPlaceResults = recommendedChatResults
    }

    @MainActor
    public func relatedPlaceQueryModel(intent:AssistiveChatHostIntent) {
        var relatedChatResults = [ChatResult]()
        
        guard cloudCache.hasPrivateCloudAccess else {
            self.relatedPlaceResults.removeAll()
            return
        }
        
        if let recommendedPlaceSearchResponses = intent.relatedPlaceSearchResponses, !recommendedPlaceSearchResponses.isEmpty {
            for response in recommendedPlaceSearchResponses {
                if !response.fsqID.isEmpty {
                    if response.fsqID == intent.selectedRecommendedPlaceSearchResponse?.fsqID, let placeSearchResponse = intent.selectedPlaceSearchResponse {
                        let results = PlaceResponseFormatter.placeChatResults(for: intent, place: placeSearchResponse, details: intent.selectedPlaceSearchDetails, recommendedPlaceResponse: intent.selectedRecommendedPlaceSearchResponse)
                        relatedChatResults.append(contentsOf: results)
                    } else {
                        let results = PlaceResponseFormatter.placeChatResults(for: intent, place: PlaceSearchResponse(fsqID: response.fsqID, name: response.name, categories: response.categories, latitude: response.latitude, longitude: response.longitude, address: response.address, addressExtended: response.formattedAddress, country: response.country, dma: response.neighborhood, formattedAddress: response.formattedAddress, locality: response.city, postCode: response.postCode, region: response.state, chains: [], link: "", childIDs: [], parentIDs: []), details: nil, recommendedPlaceResponse: response)
                        relatedChatResults.append(contentsOf: results)
                    }
                }
            }
        }
        
        relatedPlaceResults = relatedChatResults
    }
    
    @MainActor
    public func searchQueryModel(intent:AssistiveChatHostIntent) async {
        var chatResults = [ChatResult]()
        
        let existingPlaceResults = placeResults.compactMap { result in
            return result.placeResponse
        }
        
        if existingPlaceResults == intent.placeSearchResponses, let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails, let selectedPlaceChatResult = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: selectedPlaceChatResult) {
            var newResults = [ChatResult]()
            for index in 0..<placeResults.count {
                var placeResult = placeResults[index]
                if placeResult.placeResponse?.fsqID == placeChatResult.placeResponse?.fsqID, placeResult.placeDetailsResponse == nil {
                    placeResult.replaceDetails(response: selectedPlaceSearchDetails)
                    newResults.append(placeResult)
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
            for index in 0..<allDetailsResponses.count {
                let response = allDetailsResponses[index]
                
                let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response.searchResponse, details: response)
                chatResults.append(contentsOf:results)
            }
        }
        
        let allResponses = intent.placeSearchResponses
        for index in 0..<allResponses.count {
            let response = allResponses[index]
            
            var results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
            results = results.filter { result in
                if let details = intent.placeDetailsResponses {
                    for detail in details {
                        if result.placeResponse?.fsqID == detail.fsqID {
                            return false
                        }
                    }
                }
                
                return true
            }
            chatResults.append(contentsOf:results)
        }
            
            locationSearchText = intent.caption
            placeResults = chatResults
            recommendedPlaceQueryModel(intent: intent)
            relatedPlaceQueryModel(intent: intent)
    }
    
    @MainActor
    public func tellQueryModel(intent:AssistiveChatHostIntent) async throws {
        var chatResults = [ChatResult]()
        
        guard let placeResponse = intent.selectedPlaceSearchResponse, let detailsResponse = intent.selectedPlaceSearchDetails, let photosResponses = detailsResponse.photoResponses, let tipsResponses = detailsResponse.tipsResponses else {
            throw ChatResultViewModelError.MissingSelectedPlaceDetailsResponse
        }
        
        let results = PlaceResponseFormatter.placeDetailsChatResults(for: placeResponse, details:detailsResponse, photos: photosResponses, tips: tipsResponses, results: [placeResponse])
        chatResults.append(contentsOf:results)
        
        
        self.placeResults = chatResults
    }
    
    @MainActor
    public func categoricalSearchModel() async {
        let blendedResults =  categoricalResults()
        
        categoryResults.removeAll()
        categoryResults = blendedResults
    }
    
    public func cachedCategoricalResults(for group:String, identity:String)->[UserCachedRecord]? {
        return cachedCategoryRecords?.filter({ record in
            record.group == group && record.identity == identity
        })
    }
    
    public func cachedTasteResults(for group:String, identity:String)->[UserCachedRecord]? {
        return cachedTasteRecords?.filter({ record in
            record.group == group && record.identity == identity
        })
    }
    
    public func cachedLocationResults(for group:String, identity:String)->[UserCachedRecord]? {
        return cachedLocationRecords?.filter({ record in
            record.group == group && record.identity == identity
        })
    }
    
    public func cachedPlaceResults(for group:String, identity:String)->[UserCachedRecord]? {
        return cachedPlaceRecords?.filter({ record in
            record.group == group && record.identity == identity
        })
    }
    
    public func cachedPlaceResults(for group:String, title:String)->[UserCachedRecord]? {
        return cachedPlaceRecords?.filter({ record in
            record.group == group && record.title == title
        })
    }
    
    public func cachedListResults(for group:String, title:String)->[UserCachedRecord]? {
        return cachedListRecords.filter({ record in
            record.group == group && record.title == title
        })
    }
    
    private func savedCategoricalResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        
        guard let savedRecords = cachedCategoryRecords else {
            return retval
        }
        
        for record in savedRecords {
            let newChatResults = [ChatResult(title: record.title, placeResponse: nil, recommendedPlaceResponse: nil)]
            
            let newResult = CategoryResult(parentCategory: record.title, list:record.list, categoricalChatResults: newChatResults)
            retval.append(newResult)
        }
        
        return retval
    }
    
    private func allSavedResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        retval.append(contentsOf: cachedCategoryResults)
        retval.append(contentsOf: cachedTasteResults)
        retval.append(contentsOf: cachedListResults)
        
        retval.sort { result, checkResult in
            result.parentCategory < checkResult.parentCategory
        }
        
        return retval
    }
    
    private func savedTasteResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        
        guard let savedRecords = cachedTasteRecords else {
            return retval
        }
        
        for record in savedRecords {
            let newChatResults = [ChatResult(title: record.title, placeResponse: nil, recommendedPlaceResponse: nil)]
            
            let newResult = CategoryResult(parentCategory: record.title, categoricalChatResults: newChatResults)
            retval.append(newResult)
        }
        
        return retval
    }
    
    private func savedPlaceResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        
        guard let savedRecords = cachedPlaceRecords else {
            return retval
        }
        
        for record in savedRecords {
            switch record.group {
            case "Place":
                let identity = record.identity
                let placeResponse = PlaceSearchResponse(fsqID: identity, name: "", categories: [], latitude: 0, longitude: 0, address: "", addressExtended: "", country: "", dma: "", formattedAddress: "", locality: "", postCode: "", region: "", chains: [], link: "", childIDs:[], parentIDs: [])
                let newChatResults = [ChatResult(title: record.title, placeResponse: placeResponse, recommendedPlaceResponse: nil)]
                let newResult = CategoryResult(parentCategory: record.title, list:record.list, categoricalChatResults: newChatResults)
                retval.append(newResult)
            default:
                let newChatResults = [ChatResult(title: record.title, placeResponse: nil, recommendedPlaceResponse: nil)]
                let newResult = CategoryResult(parentCategory: record.title, list:record.list, categoricalChatResults: newChatResults)
                retval.append(newResult)
            }
        }
        
        return retval
    }
    
    private func savedListResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        
        let savedRecords = cachedListRecords
        guard !savedRecords.isEmpty else {
            return retval
        }
        
        var temp = [String:(String,[ChatResult])]()
        
        for record in savedRecords {
            for placeResult in cachedPlaceResults {
                if let chatResults = placeResult.categoricalChatResults, let list = placeResult.list, list == record.identity {
                    for chatResult in chatResults {
                        if let existingArray = temp[record.title] {
                            var newArray = existingArray.1
                            newArray.append(chatResult)
                            temp[record.title] = (list,newArray)
                        } else {
                            temp[record.title] = (list,[chatResult])
                        }
                    }
                }
            }
            
            if temp[record.title] == nil {
                temp[record.title] = (record.identity,[ChatResult]())
            }
        }
        
        for key in temp.keys {
            let values = temp[key]!
            let newResult = CategoryResult(parentCategory: key, list:values.0, categoricalChatResults:values.1)
            retval.append(newResult)
        }
        
        
        return retval
    }
    
    private func savedLocationResults()->[LocationResult] {
        var retval = [LocationResult]()
        guard let savedRecords = cachedLocationRecords else {
            return retval
        }
        
        for record in savedRecords {
            let identity = record.identity
            let components = identity.components(separatedBy: ",")
            guard components.count == 2, let latitude = Double(components.first!), let longitude = Double(components.last!) else {
                continue
            }
            let newLocationResult = LocationResult(locationName: record.title, location: CLLocation(latitude: latitude, longitude: longitude))
            retval.append(newLocationResult)
        }
        
        return retval
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
                        if let existingValues = result.categoricalChatResults {
                            newChatResults.append(contentsOf:existingValues)
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
    
    @MainActor
    private func tasteCategoryResults(with tastes:[String], page:Int)->[CategoryResult] {
        var retval  = [CategoryResult]()
        if page > 0 {
            retval.append(contentsOf: tasteResults)
        }
        
        for taste in tastes {
            let newChatResult = ChatResult(title: taste, placeResponse: nil, recommendedPlaceResponse: nil)
            let newCategoryResult = CategoryResult(parentCategory: taste, categoricalChatResults: [newChatResult])
            retval.append(newCategoryResult)
        }
        
        return retval
    }
    
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
        }
        
        print("Created query for search request:\(query) near location:\(String(describing: nearLocation)) with selected chat result: \(String(describing: selectedDestinationLocationChatResult))")
        if let l = location {
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
        } else if nearLocation == nil, let currentLocation = locationProvider.currentLocation(){
            let l = currentLocation
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
            
            print("Did not find a location in the query, using current location:\(String(describing: ll))")
        }
        
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = RecommendedPlaceSearchRequest(query: query, ll: ll, radius: radius, categories: categories, minPrice:minPrice, maxPrice:maxPrice, openNow: openNow, nearLocation: nearLocation, limit: limit)
        
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
        
        print("Created query for search request:\(query) near location:\(String(describing: nearLocation)) with selected chat result: \(String(describing: selectedDestinationLocationChatResult))")
        if let l = location {
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
    
    internal func fetchDetails(for responses:[PlaceSearchResponse]) async throws -> [PlaceDetailsResponse] {
        let placeDetailsResponses = try await withThrowingTaskGroup(of: PlaceDetailsResponse.self, returning: [PlaceDetailsResponse].self) { [weak self] taskGroup in
            guard let strongSelf = self else {
                return [PlaceDetailsResponse]()
            }
            for index in 0..<responses.count {
                taskGroup.addTask {
                    let response = responses[index]
                    let request = PlaceDetailsRequest(fsqID: response.fsqID, core:response.name.isEmpty, description: true, tel: true, fax: false, email: false, website: true, socialMedia: true, verified: false, hours: true, hoursPopular: true, rating: true, stats: false, popularity: true, price: true, menu: true, tastes: true, features: false)
                    print("Fetching details for \(response.name)")
                    let rawDetailsResponse = try await strongSelf.placeSearchSession.details(for: request)
                    strongSelf.analytics?.track(name: "fetchDetails")
                    
                    if strongSelf.cloudCache.hasPrivateCloudAccess {
                        let tipsRawResponse = try await strongSelf.placeSearchSession.tips(for: response.fsqID)
                        let tipsResponses = try PlaceResponseFormatter.placeTipsResponses(with: tipsRawResponse, for: response.fsqID)
                        let photosRawResponse = try await strongSelf.placeSearchSession.photos(for: response.fsqID)
                        let photoResponses = try PlaceResponseFormatter.placePhotoResponses(with: photosRawResponse, for: response.fsqID)
                        let detailsResponse = try await PlaceResponseFormatter.placeDetailsResponse(with: rawDetailsResponse, for:response, placePhotosResponses: photoResponses, placeTipsResponses: tipsResponses, previousDetails: strongSelf.assistiveHostDelegate?.queryIntentParameters?.queryIntents.last?.placeDetailsResponses, cloudCache:strongSelf.cloudCache)
                        return detailsResponse
                    }else {
                        let detailsResponse = try await PlaceResponseFormatter.placeDetailsResponse(with: rawDetailsResponse, for:response, previousDetails: strongSelf.assistiveHostDelegate?.queryIntentParameters?.queryIntents.last?.placeDetailsResponses, cloudCache:strongSelf.cloudCache)
                        return detailsResponse
                    }
                }
            }
            var allResponses = [PlaceDetailsResponse]()
            for try await value in taskGroup {
                allResponses.append(value)
            }
            
            return allResponses
        }
        
        return placeDetailsResponses
    }
    
    internal func fetchRelatedPlaces(for fsqID:String) async throws ->[RecommendedPlaceSearchResponse] {
        let rawRelatedVenuesResponse = try await personalizedSearchSession.fetchRelatedVenues(for: fsqID)
        return try PlaceResponseFormatter.relatedPlaceSearchResponses(with: rawRelatedVenuesResponse)
    }
}

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
            if let lastIntent = chatHost.queryIntentParameters?.queryIntents.last, lastIntent.caption == caption, let chatResultID = destinationChatResultID, lastIntent.selectedDestinationLocationID == chatResultID  {
                let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, selectedRecommendedPlaceSearchResponse: lastIntent.selectedRecommendedPlaceSearchResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: chatResultID, placeDetailsResponses:lastIntent.placeDetailsResponses,recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, queryParameters: queryParameters)
                
                chatHost.updateLastIntentParameters(intent:newIntent)
            } else {
                let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: checkIntent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, selectedRecommendedPlaceSearchResponse: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID:nil, placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
            }
            try await chatHost.receiveMessage(caption: checkCaption, isLocalParticipant:true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
        
    }
    
    public func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID) async throws {
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
        
        guard let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult else {
            throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
        }

        if let location = locationProvider.currentLocation(), let name = try await currentLocationName() {
            
            currentLocationResult.replaceLocation(with: location, name: name)
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
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, selectedRecommendedPlaceSearchResponse:RecommendedPlaceSearchResponse?, intent:AssistiveChatHost.Intent = .Search) async {
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let caption = chatResult.title
            
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            
            let placeSearchResponses = chatResult.placeResponse != nil ? [chatResult.placeResponse!] : [PlaceSearchResponse]()
            var destinationLocationChatResult = filteredDestinationLocationResults.first?.id
            if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult {
                destinationLocationChatResult = selectedDestinationLocationChatResult
            } else if let lastIntent = chatHost.lastLocationIntent() {
                destinationLocationChatResult = lastIntent.selectedDestinationLocationID
                selectedDestinationLocationChatResult = lastIntent.selectedDestinationLocationID
            }
            
            guard let destinationLocationChatResult = destinationLocationChatResult else {
                throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
            }
            
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
        
        var selectedDestinationChatResult = parameters.queryIntents.last?.selectedDestinationLocationID
        let selectedPlaceChatResult = selectedPlaceChatResult
        if selectedDestinationChatResult == nil, selectedPlaceChatResult == nil {
            if let selectedPlaceChatResult = selectedPlaceChatResult, let _ = placeChatResult(for: selectedPlaceChatResult) {
                
                if let firstlocationResultID = filteredLocationResults.first?.id {
                    selectedDestinationChatResult = firstlocationResultID
                } else {
                    throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
                }
            }
        } else {
            if let destinationChatResult = selectedDestinationChatResult, let _ = locationChatResult(for: destinationChatResult) {
                
            } else if let lastIntent = assistiveHostDelegate?.lastLocationIntent()  {
                let locationChatResult = locationChatResult(with:lastIntent.caption)
                selectedDestinationChatResult = locationChatResult.id
                selectedDestinationLocationChatResult = locationChatResult.id
            } else {
                throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
            }
        }
                
        if let lastIntent = queryParametersHistory.last?.queryIntents.last {
            let locationChatResult =  locationChatResult(with:lastIntent.caption)
            
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            try await searchIntent(intent: lastIntent, location: locationChatResult.location)
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
                try await searchIntent(intent: newIntent, location: locationChatResult(with:caption).location ?? locationProvider.currentLocation()! )
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
