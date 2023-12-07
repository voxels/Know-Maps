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
    public var locationProvider:LocationProvider
    public var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    public var fetchingPlaceID:ChatResult.ID?
    public var analytics:Analytics?

    @ObservedObject public var cloudCache:CloudCache
    @Published public var selectedCategoryChatResult:ChatResult.ID?
    @Published public var selectedPlaceChatResult:ChatResult.ID?
    @Published public var selectedSourceLocationChatResult:LocationResult.ID?
    @Published public var selectedDestinationLocationChatResult:LocationResult.ID?
    @Published var isFetchingPlaceDescription:Bool = false
    @Published public var searchText: String = ""
    @Published public var locationSearchText: String = ""
    @Published public var categoryResults:[CategoryResult] = [CategoryResult]()
    public var searchCategoryResults:CategoryResult = CategoryResult(parentCategory: "Search Results", categoricalChatResults: [ChatResult]())
    @Published public var placeResults:[ChatResult] = [ChatResult]()
    @Published public var locationResults:[LocationResult] = [LocationResult]()
    
    public func currentLocationName() async throws -> String? {
        if let location = locationProvider.currentLocation() {
            return try await assistiveHostDelegate?.languageDelegate.lookUpLocation(location: location)?.first?.name
        }
        return nil
    }
    
    public var filteredLocationResults:[LocationResult] {
        return locationResults
    }
    
    public var filteredSourceLocationResults:[LocationResult] {
        return filteredLocationResults
    }
    
    public var filteredDestinationLocationResults:[LocationResult] {
        return filteredLocationResults
    }
    
    public var filteredResults:[CategoryResult] {
        get {
                    
            var foundResults = [ChatResult]()
            
            var searchSection = CategoryResult(parentCategory: "Search Results", categoricalChatResults: foundResults)
            
            let chatResultsCollection = categoryResults.compactMap { categoryResult in
                return categoryResult.categoricalChatResults
            }
            
            for chatResults in chatResultsCollection {
                for result in chatResults {
                    let categoryResult = locationSearchText.components(separatedBy: "near").first?.lowercased().trimmingCharacters(in: .whitespaces) ?? locationSearchText
                    if result.title.lowercased().contains(categoryResult) || result.title.lowercased().contains(categoryResult.dropLast()) || locationSearchText.lowercased().trimmingCharacters(in: .whitespaces).contains(result.title) {
                        var searchResult = ChatResult(title: result.title, placeResponse: result.placeResponse, placeDetailsResponse: result.placeDetailsResponse)
                        searchResult.attachParentId(uuid: result.id)
                        foundResults.append(searchResult)
                    }
                }
            }
            
            searchSection.replaceChatResults(with: foundResults)
            var filteredResults = categoryResults
            
            if searchCategoryResults.categoricalChatResults.isEmpty {
                searchCategoryResults = searchSection
            } else {
                let searchCategoricalChatResultTitles = searchCategoryResults.categoricalChatResults.compactMap { result in
                    return result.title
                }
                
                let searchSectionTitles = searchSection.categoricalChatResults.compactMap { result in
                    return result.title
                }
                
                if searchCategoricalChatResultTitles != searchSectionTitles {
                    searchCategoryResults = searchSection
                }
            }
            
            if !searchCategoryResults.categoricalChatResults.isEmpty {
                if let firstCategory = categoryResults.first, firstCategory.parentCategory == "Search Results" {
                    let searchSectionTitles = searchSection.categoricalChatResults.compactMap { result in
                        result.title
                    }
                    
                    let firstCategoryTitles = firstCategory.categoricalChatResults.compactMap { result in
                        result.title
                    }
                    
                    if searchSectionTitles == firstCategoryTitles {
                        //Do nothing
                    } else {
                        filteredResults.remove(at: 0)
                        filteredResults.insert(searchCategoryResults, at: 0)
                    }
                } else {
                    filteredResults.insert(searchCategoryResults, at: 0)
                }
            }
            
            return filteredResults
             
        }
    }
    
    public var filteredPlaceResults:[ChatResult] {
        get {
            var retval = placeResults
            
            let filteredCategories = retval.filter({ result in
                if let categories = result.placeResponse?.categories {
                    if !locationSearchText.isEmpty, let chatResult = chatResult(title: locationSearchText) {
                        return categories.contains(chatResult.title.capitalized)
                    } else if selectedCategoryChatResult == nil {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            })
            
            if filteredCategories.isEmpty {
                return placeResults
            }
            
            
            for category in filteredCategories {
                retval.removeAll { result in
                    category.id == result.id
                }
            }
            
            for category in filteredCategories.reversed() {
                retval.insert(category, at: 0)
            }
            
            return retval
        }
    }
    
    public init(delegate: ChatResultViewModelDelegate? = nil, assistiveHostDelegate: AssistiveChatHostDelegate? = nil, locationProvider: LocationProvider, queryParametersHistory: [AssistiveChatHostQueryParameters] = [AssistiveChatHostQueryParameters](), fetchingPlaceID: ChatResult.ID? = nil, analytics: Analytics? = nil, cloudCache: CloudCache, selectedCategoryChatResult: ChatResult.ID? = nil, selectedPlaceChatResult: ChatResult.ID? = nil,  selectedSourceLocationChatResult: LocationResult.ID? = nil, selectedDestinationLocationChatResult: LocationResult.ID? = nil, isFetchingPlaceDescription: Bool = false, searchText: String = "", locationSearchText: String = "", categoryResults: [CategoryResult] = [CategoryResult](), searchCategoryResults: CategoryResult = CategoryResult(parentCategory: "Search Results", categoricalChatResults: [ChatResult]()), placeResults: [ChatResult] = [ChatResult](), locationResults: [LocationResult] = [LocationResult]()) {
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
        self.locationResults = [LocationResult(locationName: "Current Location", location: locationProvider.currentLocation())]
    }
    
    
    
    public func resetPlaceModel() {
        selectedPlaceChatResult = nil
        locationSearchText.removeAll()
        searchText = locationSearchText
        placeResults.removeAll()
        analytics?.track(name: "resetPlaceModel")
    }
    
    
    
    public func locationChatResult(for selectedChatResultID:LocationResult.ID)->LocationResult?{
        let selectedResult = locationResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        return selectedResult
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
    
    public func categoricalResult(for selectedCategoryResultID:ChatResult.ID)->ChatResult? {
        var results = filteredResults.first { result in
            return result.categoricalChatResults.contains { chatResult in
                return chatResult.id == selectedCategoryResultID || chatResult.parentId == selectedCategoryResultID
            }
        }
        
        if results == nil {
            results = filteredResults.first { result in
                return result.categoricalChatResults.contains { chatResult in
                    return result.result(title: chatResult.title ) != nil
                }
            }
            
            return results?.categoricalChatResults.first { chatResult in
                return chatResult.title.lowercased() == locationSearchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        else {
            return results?.result(for: selectedCategoryResultID)
        }
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
        
        if let placemarks = placemarks, let firstPlacemark = placemarks.first, let location = firstPlacemark.location {
            await MainActor.run {
                queryParametersHistory.append(parameters)
                let locations = placemarks.compactMap({ placemark in
                    return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                })
                var existingLocationNames = locationResults.map { $0.locationName }
                var newLocations = locations.filter { result in
                    !existingLocationNames.contains(result.locationName)
                }
                
                locationResults.append(contentsOf:newLocations )
                
                existingLocationNames = locationResults.map { $0.locationName }
                
                for existingLocationName in existingLocationNames {
                    if caption.lowercased().contains(existingLocationName.lowercased()), let locationResult = locationChatResult(with: existingLocationName) {
                        selectedDestinationLocationChatResult = locationResult.id
                    } else if caption == "Current Location" {
                        selectedDestinationLocationChatResult = locationResults.first?.id
                    }
                }

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
            let request = await placeSearchRequest(intent: intent)
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
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: caption, isLocalParticipant: true)
            try await model(intent: newIntent)
        }
        
        if let placemarks = try await checkSearchTextForLocations(with: caption) {
            let locations = placemarks.compactMap({ placemark in
                return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
            })
            let existingLocationNames = locationResults.map { $0.locationName }
            var newLocations = locations.filter { result in
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
        if intent.selectedPlaceSearchDetails != nil, let selectedPlaceChatResult = selectedPlaceChatResult, let placeChatResult = placeChatResult(for: selectedPlaceChatResult), placeChatResult.title == intent.caption {
            await searchQueryModel(intent: intent)
            return
        }
        
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
        
        if existingPlaceResults == intent.placeSearchResponses, let selectedPlaceSearchDetails = intent.selectedPlaceSearchDetails, let selectedPlaceChatResult, let placeChatResult = placeChatResult(for: selectedPlaceChatResult) {
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
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
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
            } else {
                locationSearchText = intent.caption
                placeResults = chatResults
                return
            }
            
            let categoryCodes = chatHost.categoryCodes
            for categoryCode in categoryCodes {
                if categoryCode.keys.contains(intent.caption.lowercased().trimmingCharacters(in: .whitespaces)) {
                    self.placeResults = chatResults
                    locationSearchText = intent.caption
                }
                
                for values in categoryCode.values {
                    for value in values {
                        if let valueCategory =  value["category"], valueCategory.lowercased().contains(intent.caption.lowercased().trimmingCharacters(in: .whitespaces)), locationSearchText != intent.caption {
                            self.placeResults = chatResults
                            locationSearchText = intent.caption
                        }
                    }
                }
            }
            
            if placeResults != chatResults {
                locationSearchText = intent.caption
                placeResults = chatResults
            }
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
                        let existingValues = result.categoricalChatResults
                        newChatResults.append(contentsOf:existingValues)
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
    
    
    private func placeSearchRequest(intent:AssistiveChatHostIntent) async ->PlaceSearchRequest {
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
        
        print("Created query for search request:\(query) near location:\(String(describing: nearLocation))")
        if nearLocation == nil, let currentLocation = locationProvider.currentLocation(){
            let l = currentLocation
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
            
            print("Did not find a location in the query, using current location:\(String(describing: ll))")
        } else if let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationResult = locationChatResult(for: selectedDestinationLocationChatResult), let l = locationResult.location {
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
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
    
    
    public func didSearch(caption: String, selectedDestinationChatResultID:LocationResult.ID?) async throws {
        guard selectedDestinationChatResultID != nil else {
            resetPlaceModel()
            return
        }
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let intent:AssistiveChatHost.Intent = chatHost.determineIntent(for: caption)
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            if let lastIntent = chatHost.queryIntentParameters.queryIntents.last, lastIntent.caption == caption {
                let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, placeDetailsResponses:lastIntent.placeDetailsResponses, queryParameters: queryParameters)
                
                chatHost.updateLastIntentParameters(intent:newIntent)
            } else {
                let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
            }
            try await chatHost.receiveMessage(caption: caption, isLocalParticipant:true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
        
    }
    
    public func updateLastIntentParameter(for placeChatResult:ChatResult) async throws {
        guard let chatHost = assistiveHostDelegate, let lastIntent = assistiveHostDelegate?.queryIntentParameters.queryIntents.last, lastIntent.placeSearchResponses.count > 0 else {
            return
        }
        
        let queryParameters = try await chatHost.defaultParameters(for: placeChatResult.title)
        let newIntent = AssistiveChatHostIntent(caption: placeChatResult.title, intent: .Search, selectedPlaceSearchResponse: placeChatResult.placeResponse, selectedPlaceSearchDetails:placeChatResult.placeDetailsResponse, placeSearchResponses: lastIntent.placeSearchResponses, placeDetailsResponses: nil, queryParameters: queryParameters)
        
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
    
    public func didTap(placeChatResult: ChatResult) async throws {
        guard let lastIntent = assistiveHostDelegate?.queryIntentParameters.queryIntents.last, lastIntent.placeSearchResponses.count > 0 else {
            return
        }
        
        try await updateLastIntentParameter(for: placeChatResult)
    }
    
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?) async {
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let caption = chatResult.title
            let intent = AssistiveChatHost.Intent.Search
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: selectedPlaceSearchResponse, selectedPlaceSearchDetails: selectedPlaceSearchDetails, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: chatResult.title, isLocalParticipant: true)
        } catch {
            analytics?.track(name: "error \(error)")
            print(error)
        }
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        
        if let lastIntent = queryParametersHistory.last?.queryIntents.last {
            try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
            
            guard let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationResult = locationChatResult(for: selectedDestinationLocationChatResult), let destinationLocation = locationResult.location else {
                throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
            }
            
            try await searchIntent(intent: lastIntent, location: destinationLocation)
            try await didUpdateQuery(with: parameters)
        } else {
            do {
                guard let chatHost = self.assistiveHostDelegate else {
                    return
                }
                
                let intent:AssistiveChatHost.Intent = chatHost.determineIntent(for: caption)
                let queryParameters = try await chatHost.defaultParameters(for: caption)
                let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
                
                chatHost.appendIntentParameters(intent: newIntent)
                try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
                
                
                guard let selectedDestinationLocationChatResult = selectedDestinationLocationChatResult, let locationResult = locationChatResult(for: selectedDestinationLocationChatResult), let destinationLocation = locationResult.location else {
                    throw ChatResultViewModelError.MissingSelectedDestinationLocationChatResult
                }
                
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
