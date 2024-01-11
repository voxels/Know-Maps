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
    case MissingSelectedPlaceSeaquerchResponse
    case MissingSelectedPlaceDetailsResponse
    case NoAutocompleteResultsFound
    case MissingCurrentLocation
    case MissingSelectedDestinationLocationChatResult
}

@MainActor
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
    @Published public var cachedCategoryRecords:[UserCachedRecord]?
    @Published public var cachedListRecords:[UserCachedRecord]?
    @Published public var suggestedListRecords:[UserCachedRecord]?
    @Published public var cachedCategoryResults = [CategoryResult]()
    @Published public var cachedLocationRecords:[UserCachedRecord]?
    @Published public var cachedLocationResults = [LocationResult]()
    @Published public var selectedCategoryResult:CategoryResult.ID?
    @Published public var selectedSavedCategoryResult:CategoryResult.ID?
    @Published public var selectedTasteCategoryResult:CategoryResult.ID?
    @Published public var selectedCategoryChatResult:ChatResult.ID?
    @Published public var selectedPlaceChatResult:ChatResult.ID?
    @Published public var selectedSourceLocationChatResult:LocationResult.ID?
    @Published public var selectedDestinationLocationChatResult:LocationResult.ID?
    @Published public var selectedSuggestedListRecord:UserCachedRecord?
    @Published var isFetchingPlaceDescription:Bool = false
    @Published public var searchText: String = ""
    @Published public var locationSearchText: String = ""
    @Published public var categoryResults:[CategoryResult] = [CategoryResult]()
    @Published public var tasteResults:[CategoryResult] = [CategoryResult]()
    public var searchCategoryResults:CategoryResult = CategoryResult(parentCategory: "Search Results", categoricalChatResults: [ChatResult]())
    @Published public var placeResults:[ChatResult] = [ChatResult]()
    @Published public var locationResults:[LocationResult] = [LocationResult]()
    
    public func currentLocationName() async throws -> String? {
        if let location = locationProvider.currentLocation() {
            return try await assistiveHostDelegate?.languageDelegate.lookUpLocation(location: location)?.first?.name ?? "Current Location"
        }
        return nil
    }
    
    public var filteredSuggestedListRecords:[UserCachedRecord] {
        guard let suggestedListRecords = suggestedListRecords else {
            return [UserCachedRecord]()
        }
        
        return suggestedListRecords
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
            allLocationResults.insert(LocationResult(locationName: "Current Location", location: locationProvider.currentLocation()), at:0)
            return allLocationResults
        } else {
            var allLocationResults = locationResults.sorted { firstResult, secondResult in
                return firstResult.locationName <= secondResult.locationName
            }
            allLocationResults.insert(LocationResult(locationName: "Current Location", location: locationProvider.currentLocation()), at:0)
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
            let retval = placeResults.sorted { result, checkResult in
                return result.title <= checkResult.title
            }
                    
            return retval
        }
    }
    
    public init(delegate: ChatResultViewModelDelegate? = nil, assistiveHostDelegate: AssistiveChatHostDelegate? = nil, locationProvider: LocationProvider, queryParametersHistory: [AssistiveChatHostQueryParameters] = [AssistiveChatHostQueryParameters](), fetchingPlaceID: ChatResult.ID? = nil, analytics: Analytics? = nil, cloudCache:CloudCache, selectedCategoryChatResult: ChatResult.ID? = nil, selectedPlaceChatResult: ChatResult.ID? = nil,  selectedSourceLocationChatResult: LocationResult.ID? = nil, selectedDestinationLocationChatResult: LocationResult.ID? = nil, isFetchingPlaceDescription: Bool = false, searchText: String = "", locationSearchText: String = "", categoryResults: [CategoryResult] = [CategoryResult](), searchCategoryResults: CategoryResult = CategoryResult(parentCategory: "Search Results", categoricalChatResults: [ChatResult]()), placeResults: [ChatResult] = [ChatResult](), locationResults: [LocationResult] = [LocationResult]()) {
        self.delegate = delegate
        self.assistiveHostDelegate = assistiveHostDelegate
        self.locationProvider = locationProvider
        self.queryParametersHistory = queryParametersHistory
        self.fetchingPlaceID = fetchingPlaceID
        self.analytics = analytics
        self.cloudCache = cloudCache
        self.selectedCategoryChatResult = selectedCategoryChatResult
        self.selectedPlaceChatResult = selectedPlaceChatResult
        self.selectedSourceLocationChatResult = selectedSourceLocationChatResult
        self.selectedDestinationLocationChatResult = selectedDestinationLocationChatResult
        self.isFetchingPlaceDescription = isFetchingPlaceDescription
        self.searchText = searchText
        self.locationSearchText = locationSearchText
        self.categoryResults = categoryResults
        self.searchCategoryResults = searchCategoryResults
        self.placeResults = placeResults
        self.locationResults = locationResults
        self.personalizedSearchSession = PersonalizedSearchSession(cloudCache: cloudCache)
    }
    
    @discardableResult
    public func retrieveFsqUser() async throws -> Bool {
        if !cloudCache.hasPrivateCloudAccess {
            return false
        }
        
        personalizedSearchSession.fsqIdentity = try await personalizedSearchSession.fetchManagedUserIdentity()
        personalizedSearchSession.fsqAccessToken = try await personalizedSearchSession.fetchManagedUserAccessToken()
        
        return personalizedSearchSession.fsqAccessToken != nil
    }
    
    public func resetPlaceModel() {
        selectedPlaceChatResult = nil
        locationSearchText.removeAll()
        searchText = locationSearchText
        placeResults.removeAll()
        analytics?.track(name: "resetPlaceModel")
    }
    
    public func refreshTastes() async throws {
        let tastes = try await personalizedSearchSession.fetchTastes()
        tasteResults = tasteCategoryResults(with: tastes)
    }
    
    public func refreshCachedLocations(cloudCache:CloudCache) async throws {
        cachedLocationRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Location")
        cachedLocationResults = savedLocationResults()
    }
    
    public func refreshCachedCategories(cloudCache:CloudCache) async throws {
        cachedCategoryRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Category")
        cachedCategoryResults = savedCategoricalResults()
    }
    
    public func refreshSuggestedLists(cloudCache:CloudCache, with chatResult:ChatResult) async throws {
        var retval = [UserCachedRecord]()
        cachedListRecords = try await cloudCache.fetchGroupedUserCachedRecords(for: "Place")
        if let cachedListRecords = cachedListRecords {
            retval.append(contentsOf: cachedListRecords)
        }
        if let categories = chatResult.placeResponse?.categories {
            for category in categories {
                let categoryRecord = UserCachedRecord(recordId: "", group: "Place", identity:chatResult.placeResponse!.fsqID, title: category, icons: "")
                retval.append(categoryRecord)
            }
        }
        if let tastes = chatResult.placeDetailsResponse?.tastes {
            for taste in tastes {
                let tasteRecord = UserCachedRecord(recordId: "", group: "Place", identity:chatResult.placeResponse!.fsqID, title: taste, icons: "")
                retval.append(tasteRecord)
            }
        }
        suggestedListRecords = retval
    }
    
    public func appendCachedCategory(with record:UserCachedRecord) {
        cachedCategoryRecords?.append(record)
        cachedCategoryResults = savedCategoricalResults()
    }
    
    public func cachedCategories(contains category:String)->Bool {
        guard let cachedRecords = cachedCategoryRecords, !cachedRecords.isEmpty else {
            return false
        }
        
        return cachedRecords.contains { record in
            record.identity == category
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
        let selectedResult = locationResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        if let selectedResult = selectedResult {
            return selectedResult
        }
        
        let savedResult = cachedLocationResults.first(where: {checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        return savedResult
    }
    
    public func locationChatResult(with title:String)->LocationResult? {
        let selectedResult = locationResults.first { checkResult in
            checkResult.locationName == title
        }
        return selectedResult
    }
    
    public func placeChatResult(for selectedChatResultID:ChatResult.ID)->ChatResult?{
        let selectedResult = placeResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        return selectedResult
    }
    
    public func placeChatResult(for selectedPlaceFsqID:String)->ChatResult? {
        let selectedResult = placeResults.first(where: { checkResult in
            return checkResult.placeResponse?.fsqID == selectedPlaceFsqID
        })
        
        return selectedResult
    }
    
    public func savedCategoricalResult(for selectedCategoryID:CategoryResult.ID)->ChatResult? {
        let searchCategories = cachedCategoryResults
        
        
        let parentCategory = searchCategories.first { result in
            return result.id == selectedCategoryID
        }

        guard let parentCategory = parentCategory else {
            return nil
        }
        
        if parentCategory.id == selectedCategoryID {
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
    
    public func categoricalResult(for selectedCategoryID:CategoryResult.ID)->ChatResult? {
        var searchCategories = [CategoryResult]()
        for result in filteredResults {
            if let children = result.children {
                for child in children {
                    searchCategories.append(child)
                }
            }
        }
        
        
        let parentCategory = searchCategories.first { result in
            if let children = result.children {
                for child in children {
                    if child.id == selectedCategoryID {
                        print("found match:\(child.id)")
                    }
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
    
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        guard let chatHost = self.assistiveHostDelegate else {
            return
        }
        
        let placemarks = try? await checkSearchTextForLocations(with: caption)
        
        if let placemarks = placemarks, let firstPlacemark = placemarks.first, let _ = firstPlacemark.location {
            await MainActor.run {
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
    
    public func searchIntent(intent:AssistiveChatHostIntent, location:CLLocation) async throws {
        switch intent.intent {
        case .Search:
            let request = await placeSearchRequest(intent: intent, location:location)
            let rawQueryResponse = try await placeSearchSession.query(request:request, location: location)
            let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse) : intent.placeSearchResponses
            intent.placeSearchResponses = placeSearchResponses
            analytics?.track(name: "searchIntentWithSearch")
        case .Autocomplete:
            let autocompleteResponse = try await placeSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, location: location)
            let placeSearchResponses = intent.placeSearchResponses.isEmpty ? try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse) : intent.placeSearchResponses
            intent.placeSearchResponses = placeSearchResponses
            analytics?.track(name: "searchIntentWithAutocomplete")
        }
    }
    
    public func detailIntent( intent: AssistiveChatHostIntent) async throws {
        if intent.selectedPlaceSearchDetails != nil {
            return
        }
        if intent.placeSearchResponses.count > 0, let placeSearchResponse = intent.selectedPlaceSearchResponse {
            intent.selectedPlaceSearchDetails = try await fetchDetails(for: [placeSearchResponse]).first
        }
    }
    
    public func `autocompletePlaceModel`(caption:String, intent: AssistiveChatHostIntent, location:CLLocation) async throws {
        
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
        
        await MainActor.run {
            if placeResults != chatResults {
                placeResults = chatResults
            }
        }
    }
    
    public func
    refreshModel(queryIntents:[AssistiveChatHostIntent]? = nil) async throws {
        guard let chatHost = self.assistiveHostDelegate else {
            return
        }
        
        var caption = ""
        
        if let lastIntent = queryIntents?.last {
            caption = lastIntent.caption
            
            if let selectedPlaceChatResult = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: selectedPlaceChatResult) {
                searchText = placeChatResult.title
            } else {
                searchText = caption
            }
            try await model(intent: lastIntent)
        } else {
            caption = locationSearchText
            let intent = chatHost.determineIntent(for: caption)
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: filteredDestinationLocationResults.first!.id, placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: caption, isLocalParticipant: true)
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
        case .Search:
            try await detailIntent(intent: intent)
            await searchQueryModel(intent: intent)
            analytics?.track(name: "modelSearchQueryBuilt")
        case .Autocomplete:
            do {
                if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationResult = locationChatResult(for: selectedDestinationLocationChatResult), let finalLocation = locationResult.location {
                    try await autocompletePlaceModel(caption: intent.caption, intent: intent, location: finalLocation)
                    analytics?.track(name: "modelAutocompletePlaceModelBuilt")
                }
            } catch {
                analytics?.track(name: "error \(error)")
                print(error)
            }
        }
    }
    
    
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
        
        await MainActor.run {            
            if selectedPlaceChatResult == nil {
                if let _ = intent.selectedPlaceSearchResponse?.name {
                    if let selectedPlaceSearchResponse = intent.selectedPlaceSearchResponse, selectedPlaceSearchResponse.name == intent.caption {
                        for result in chatResults {
                            if result.placeResponse?.fsqID == selectedPlaceSearchResponse.fsqID {
                                selectedPlaceChatResult = result.id
                            }
                        }
                    }
                    return
                }
            }
            
            locationSearchText = intent.caption
            placeResults = chatResults
        }
    }
    
    public func tellQueryModel(intent:AssistiveChatHostIntent) async throws {
        var chatResults = [ChatResult]()
        
        guard let placeResponse = intent.selectedPlaceSearchResponse, let detailsResponse = intent.selectedPlaceSearchDetails, let photosResponses = detailsResponse.photoResponses, let tipsResponses = detailsResponse.tipsResponses else {
            throw ChatResultViewModelError.MissingSelectedPlaceDetailsResponse
        }
        
        let results = PlaceResponseFormatter.placeDetailsChatResults(for: placeResponse, details:detailsResponse, photos: photosResponses, tips: tipsResponses, results: [placeResponse])
        chatResults.append(contentsOf:results)
        
        
        await MainActor.run {
            self.placeResults = chatResults
        }
    }
    
    public func categoricalSearchModel() async {
        let blendedResults =  categoricalResults()
        
        await MainActor.run {
            categoryResults.removeAll()
            categoryResults = blendedResults
        }
    }
    
    public func cachedCategoricalResults(for group:String, identity:String)->[UserCachedRecord]? {
        return cachedCategoryRecords?.filter({ record in
            record.group == group && record.identity == identity
        })
    }
    
    public func cachedLocationResults(for group:String, identity:String)->[UserCachedRecord]? {
        return cachedLocationRecords?.filter({ record in
            record.group == group && record.identity == identity
        })
    }
    
    private func savedCategoricalResults()->[CategoryResult] {
        var retval = [CategoryResult]()
        
        guard let savedRecords = cachedCategoryRecords else {
            return retval
        }
        
        for record in savedRecords {
            let newChatResults = [ChatResult(title: record.title, placeResponse: nil)]

            let newResult = CategoryResult(parentCategory: record.title, categoricalChatResults: newChatResults)
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
                        let chatResult = ChatResult(title:category, placeResponse:nil)
                        newChatResults.append(chatResult)
                    }
                }
            }
            
            for key in categoryCode.keys {
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
    
    private func tasteCategoryResults(with tastes:[String])->[CategoryResult] {
        var retval  = [CategoryResult]()
        for taste in tastes {
            let newChatResult = ChatResult(title: taste, placeResponse: nil)
            let newCategoryResult = CategoryResult(parentCategory: taste, categoricalChatResults: [newChatResult])
            retval.append(newCategoryResult)
        }
        
        return retval
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
                    let request = PlaceDetailsRequest(fsqID: response.fsqID, description: true, tel: true, fax: false, email: false, website: true, socialMedia: true, verified: false, hours: true, hoursPopular: true, rating: true, stats: false, popularity: true, price: true, menu: true, tastes: true, features: false)
                    print("Fetching details for \(response.name)")
                    let rawDetailsResponse = try await strongSelf.placeSearchSession.details(for: request)
                    await strongSelf.analytics?.track(name: "fetchDetails")
                    let detailsResponse = try await PlaceResponseFormatter.placeDetailsResponse(with: rawDetailsResponse, for: response, previousDetails: strongSelf.assistiveHostDelegate?.queryIntentParameters.queryIntents.last?.placeDetailsResponses, cloudCache:strongSelf.cloudCache)
                    return detailsResponse
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
    
}

extension ChatResultViewModel : AssistiveChatHostMessagesDelegate {
    
    
    public func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID) async throws {
        
        let checkCaption = caption

        let destinationChatResultID = selectedDestinationChatResultID

        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let intent:AssistiveChatHost.Intent = chatHost.determineIntent(for: checkCaption)
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            if let lastIntent = chatHost.queryIntentParameters.queryIntents.last, lastIntent.caption == caption, lastIntent.selectedDestinationLocationID == destinationChatResultID {
                let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: intent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: destinationChatResultID, placeDetailsResponses:lastIntent.placeDetailsResponses, queryParameters: queryParameters)
                
                chatHost.updateLastIntentParameters(intent:newIntent)
            } else {
                let newIntent = AssistiveChatHostIntent(caption: checkCaption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: destinationChatResultID, placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
            }
            try await chatHost.receiveMessage(caption: checkCaption, isLocalParticipant:true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
        
    }
    
    public func updateLastIntentParameter(for placeChatResult:ChatResult, selectedDestinationChatResultID:LocationResult.ID) async throws {
        guard let chatHost = assistiveHostDelegate, let lastIntent = assistiveHostDelegate?.queryIntentParameters.queryIntents.last, lastIntent.placeSearchResponses.count > 0 else {
            return
        }
        
        let queryParameters = try await chatHost.defaultParameters(for: placeChatResult.title)
        let newIntent = AssistiveChatHostIntent(caption: placeChatResult.title, intent: .Search, selectedPlaceSearchResponse: placeChatResult.placeResponse, selectedPlaceSearchDetails:placeChatResult.placeDetailsResponse, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: selectedDestinationChatResultID, placeDetailsResponses: nil, queryParameters: queryParameters)
        
        guard let tappedResultPlaceResponse = placeChatResult.placeResponse else {
            chatHost.updateLastIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: newIntent.caption, isLocalParticipant: true)
            return
        }
        
        try await self.detailIntent(intent: newIntent)
        
        for result in newIntent.placeSearchResponses {
            if result.fsqID == tappedResultPlaceResponse.fsqID {
                newIntent.selectedPlaceSearchResponse = result
            }
        }
        
        if let placeDetailsResponses = newIntent.placeDetailsResponses {
            for result in placeDetailsResponses {
                if result.fsqID == tappedResultPlaceResponse.fsqID {
                    newIntent.selectedPlaceSearchDetails = result
                }
            }
        }
        
        chatHost.updateLastIntentParameters(intent: newIntent)
        try await didUpdateQuery(with: chatHost.queryIntentParameters)
    }
    
    public func didTapMarker(with fsqId:String?) async throws {
        guard let fsqId = fsqId else {
            return
        }
        
        if let placeChatResult = placeChatResult(for:fsqId) {
            selectedPlaceChatResult = placeChatResult.id
        }
    }
    
    public func didTap(placeChatResult: ChatResult) async throws {
        guard let lastIntent = assistiveHostDelegate?.queryIntentParameters.queryIntents.last, lastIntent.placeSearchResponses.count > 0, let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult else {
            return
        }
        
        try await updateLastIntentParameter(for: placeChatResult, selectedDestinationChatResultID:selectedDestinationLocationChatResult)
    }
    
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?) async {
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let caption = chatResult.title
            let intent = AssistiveChatHost.Intent.Search
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: selectedPlaceSearchResponse, selectedPlaceSearchDetails: selectedPlaceSearchDetails, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationLocationChatResult ?? filteredDestinationLocationResults.first!.id, placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: chatResult.title, isLocalParticipant: true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        
        var destinationLocation = locationProvider.currentLocation()
        var selectedDestinationChatResult = filteredDestinationLocationResults.first!.id
        
        if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let selectedDestination = locationChatResult(for: selectedDestinationLocationChatResult), let location = selectedDestination.location {
            destinationLocation = location
            selectedDestinationChatResult = selectedDestinationLocationChatResult
        }
        
        guard let destinationLocation = destinationLocation else {
            throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
        }
        
        if let lastIntent = queryParametersHistory.last?.queryIntents.last {
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            try await searchIntent(intent: lastIntent, location: destinationLocation)
            try await didUpdateQuery(with: parameters)
        } else {
            do {
                guard let chatHost = self.assistiveHostDelegate else {
                    return
                }
                
                let intent:AssistiveChatHost.Intent = chatHost.determineIntent(for: caption)
                let queryParameters = try await chatHost.defaultParameters(for: caption)
                let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), selectedDestinationLocationID: selectedDestinationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
                try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
                try await searchIntent(intent: newIntent, location: destinationLocation)
                try await didUpdateQuery(with: parameters)
            } catch {
                analytics?.track(name: "error \(error)")
                print(error)
            }
        }
    }
    
    public func didUpdateQuery(with parameters: AssistiveChatHostQueryParameters) async throws {
        try await refreshModel(queryIntents: parameters.queryIntents)
    }
    
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
    
    public func willReceiveStreamingResult(for chatResultID: ChatResult.ID) async {
        fetchingPlaceID = chatResultID
        await MainActor.run {
            isFetchingPlaceDescription = true
        }
    }
    
    public func didFinishStreamingResult() async {
        if let fetchingPlaceID = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: fetchingPlaceID), let fsqid = placeChatResult.placeDetailsResponse?.fsqID, let description = placeChatResult.placeDetailsResponse?.description {
            assistiveHostDelegate?.cache.storeGeneratedDescription(for: fsqid, description:description)
        }
        
        fetchingPlaceID = nil
        await MainActor.run {
            isFetchingPlaceDescription = false
        }
    }
    
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
                    let newPlaceResult = ChatResult(title: placeResult.title, placeResponse: placeResult.placeResponse, placeDetailsResponse: newDetailsResponse)
                    newPlaceResults.append(newPlaceResult)
                    selectedId = newPlaceResult.id
                } else {
                    newPlaceResults.append(placeResult)
                }
            }
            
            
            await MainActor.run {
                placeResults = newPlaceResults
            }
            
            await MainActor.run {
                selectedPlaceChatResult = selectedId
            }
        }
    }
}
