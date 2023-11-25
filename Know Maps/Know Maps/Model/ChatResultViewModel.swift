//
//  ChatResultViewModel.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation

enum ChatResultViewModelError : Error {
    case MissingLastIntent
    case MissingSelectedPlaceSeaquerchResponse
    case MissingSelectedPlaceDetailsResponse
    case NoAutocompleteResultsFound
    case MissingCurrentLocation
}

public protocol ChatResultViewModelDelegate : AnyObject {
    func didUpdateModel(for location:CLLocation?)
}

@MainActor
public class ChatResultViewModel : ObservableObject {
    public weak var delegate:ChatResultViewModelDelegate?
    public weak var assistiveHostDelegate:AssistiveChatHostDelegate?
    private let placeSearchSession:PlaceSearchSession = PlaceSearchSession()
    public var locationProvider:LocationProvider
    public var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    public var fetchingPlaceID:ChatResult.ID?
    
    @Published public var selectedCategoryChatResult:ChatResult.ID?
    @Published public var selectedPlaceChatResult:ChatResult.ID?
    @Published public var selectedLocationChatResult:LocationResult.ID?
    @Published var isFetchingPlaceDescription:Bool = false
    @Published public var searchText: String = ""
    @Published public var locationSearchText: String = ""
    @Published public var categoryResults:[CategoryResult] = [CategoryResult]()
    @Published public var placeResults:[ChatResult] = [ChatResult]()
    @Published public var locationResults:[LocationResult] = [LocationResult]()
    
    public var filteredLocationResults:[LocationResult] {
        get {
            var retval = [LocationResult]()
            if let location = locationProvider.currentLocation() {
                let newLocationResult = LocationResult(locationName: "Current Location", location: location)
                retval.append(newLocationResult)
            }
            
            retval.append(contentsOf: locationResults)
            return retval
        }
    }
    
    public var filteredResults:[CategoryResult] {
        get {
            var foundResults = [ChatResult]()
            
            let chatResultsCollection = categoryResults.compactMap { categoryResult in
                return categoryResult.categoricalChatResults
            }
            
            for chatResults in chatResultsCollection {
                for result in chatResults {
                    if result.title.lowercased().contains(searchText.lowercased().trimmingCharacters(in: .whitespaces)) || searchText.lowercased().trimmingCharacters(in: .whitespaces).contains(result.title) {
                        foundResults.append(ChatResult(title: result.title, placeResponse: result.placeResponse, placeDetailsResponse: result.placeDetailsResponse))
                    }
                }
            }
            
            if foundResults.isEmpty {
                return categoryResults
            }
            
            let searchSection = CategoryResult(parentCategory: "Search Results", categoricalChatResults: foundResults)
            
            var filteredResults = [searchSection]
            filteredResults.append(contentsOf: categoryResults)
            return filteredResults
        }
    }
    
    public var filteredPlaceResults:[ChatResult] {
        get {
            return placeResults.sorted { result, checkResult in
                if result.id == selectedPlaceChatResult {
                    return true
                }
                
                if checkResult.id == selectedPlaceChatResult {
                    return false
                }
                let location = locationProvider.queryLocation
                if let resultPlaceResponse = result.placeResponse, let checkResultPlaceResponse = checkResult.placeResponse {
                    let resultCoordinate = CLLocation(latitude: resultPlaceResponse.latitude, longitude: resultPlaceResponse.longitude)
                    let checkResultCoordinate = CLLocation(latitude: checkResultPlaceResponse.latitude, longitude: checkResultPlaceResponse.longitude)
                    return location.distance(from: resultCoordinate) < location.distance(from: checkResultCoordinate)
                }
                
                return false
            }
        }
    }
    
    public init(delegate: ChatResultViewModelDelegate? = nil, assistiveHostDelegate: AssistiveChatHostDelegate? = nil, locationProvider: LocationProvider,  queryParametersHistory: [AssistiveChatHostQueryParameters] = [AssistiveChatHostQueryParameters]() ) {
        self.delegate = delegate
        self.assistiveHostDelegate = assistiveHostDelegate
        self.locationProvider = locationProvider
        self.queryParametersHistory = queryParametersHistory
    }
    
    public func resetPlaceModel() {
        self.selectedPlaceChatResult = nil
        self.placeResults = [ChatResult]()
    }
    
    public func placeChatResult(for selectedChatResultID:ChatResult.ID)->ChatResult?{
        let selectedResult = placeResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        return selectedResult
    }
    
    public func categoricalResult(for selectedCategoryResultID:ChatResult.ID)->ChatResult? {
        let results = categoryResults.first { result in
            return result.categoricalChatResults.contains { chatResult in
                return chatResult.id == selectedCategoryResultID
            }
        }
        
        
        return results?.categoricalChatResults.compactMap { result in
            if result.id == selectedCategoryResultID {
                return result
            }
            return nil
        }.first        
    }
    
    public func chatResult(title:String)->ChatResult? {
        return categoryResults.compactMap { categoryResult in
            return categoryResult.result(title: title)
        }.first
    }
    
    public func checkSearchTextForLocations(with text:String) async throws ->[CLPlacemark]? {
        let tags = try assistiveHostDelegate?.tags(for: text)
        
        if let _ = chatResult(title: text) {
            return nil
        } else {
            return try await assistiveHostDelegate?.nearLocationCoordinate(for: text, tags:tags)
        }
    }
    
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        guard var finalLocation = locationProvider.lastKnownLocation else {
            throw ChatResultViewModelError.MissingCurrentLocation
        }

        let placemarks = try? await checkSearchTextForLocations(with: caption)
        
        if let placemarks = placemarks, let location = placemarks.first?.location, chatResult(title: caption) == nil {
            finalLocation = location
            
            await MainActor.run {
                queryParametersHistory.append(parameters)
                locationProvider.queryLocation = finalLocation
                locationResults = placemarks.compactMap({ placemark in
                    return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                })
                locationSearchText = caption
            }
        }  else {
            await MainActor.run {
                queryParametersHistory.append(parameters)
                locationProvider.queryLocation = finalLocation
                locationResults.removeAll()
            }
        }
    }
    
    public func searchIntent(intent:AssistiveChatHostIntent, location:CLLocation) async throws {
        switch intent.intent {
        case .Search:
            let request = await placeSearchRequest(intent: intent)
            let rawQueryResponse = try await placeSearchSession.query(request:request, location: location)
            let placeSearchResponses = try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse)
            intent.placeSearchResponses = placeSearchResponses
        case .Autocomplete:
            let autocompleteResponse = try await placeSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, location: location)
            let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
            intent.placeSearchResponses = placeSearchResponses
        }
    }
    
    public func detailIntent( intent: AssistiveChatHostIntent) async throws {
        if intent.placeSearchResponses.count > 0, let placeSearchResponse = intent.selectedPlaceSearchResponse {
            intent.placeDetailsResponses = try await fetchDetails(for: [placeSearchResponse])
        }
    }
    
    public func autocompletePlaceModel(caption:String, intent: AssistiveChatHostIntent, location:CLLocation) async throws {
        let autocompleteResponse = try await placeSearchSession.autocomplete(caption: caption, parameters: intent.queryParameters, location: location)
        let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse)
        intent.placeSearchResponses = placeSearchResponses
        
        var chatResults = [ChatResult]()
        let allResponses = intent.placeSearchResponses
        for index in 0..<allResponses.count {
            let response = allResponses[index]
            
            let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
            chatResults.append(contentsOf:results)
        }
        
        await MainActor.run {
            self.placeResults = chatResults
        }
    }
    
    public func refreshModel(queryIntents:[AssistiveChatHostIntent]? = nil) async throws {
        guard let chatHost = self.assistiveHostDelegate else {
            return
        }
        
        if let lastIntent = queryIntents?.last {
            try await model(intent:lastIntent)
        } else {
            let caption = searchText
            let intent = chatHost.determineIntent(for: caption)
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
            chatHost.appendIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: caption, isLocalParticipant: true)
            if let placemarks = try await checkSearchTextForLocations(with: caption) {
                locationResults = placemarks.compactMap({ placemark in
                    return LocationResult(locationName: placemark.name ?? "Unknown Location", location: placemark.location)
                })
            }

            try await model(intent: newIntent)
        }
    }
    
    public func model(intent:AssistiveChatHostIntent) async throws {
        switch intent.intent {
        case .Search:
            try await detailIntent(intent: intent)
            await searchQueryModel(intent: intent)
        case .Autocomplete:
            do {
                guard var finalLocation = locationProvider.lastKnownLocation else {
                    throw ChatResultViewModelError.MissingCurrentLocation
                }
                
                let tags = try assistiveHostDelegate?.tags(for: intent.caption)
                let nearLocation = try await assistiveHostDelegate?.nearLocationCoordinate(for: intent.caption, tags:tags)
                if let nearLocation = nearLocation, let location = nearLocation.first?.location {
                    finalLocation = location
                }
                
                await MainActor.run {
                    locationProvider.queryLocation = finalLocation
                }
                
                try await autocompletePlaceModel(caption: intent.caption, intent: intent, location: finalLocation)
            } catch {
                print(error)
            }
        }
    }
    
    
    public func searchQueryModel(intent:AssistiveChatHostIntent ) async {
        var chatResults = [ChatResult]()
        if let allDetailsResponses = intent.placeDetailsResponses {
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
            
            if let title = intent.selectedPlaceSearchResponse?.name {
                self.searchText = title
                
                if let selectedPlaceSearchResponse = intent.selectedPlaceSearchResponse, selectedPlaceSearchResponse.name == intent.caption {
                    for result in chatResults {
                        if result.placeResponse?.fsqID == selectedPlaceSearchResponse.fsqID {
                            selectedPlaceChatResult = result.id
                        }
                    }
                }
                return
            }
            
            let categoryCodes = chatHost.categoryCodes
            for categoryCode in categoryCodes {
                if categoryCode.keys.contains(intent.caption.lowercased().trimmingCharacters(in: .whitespaces)) {
                    self.searchText = intent.caption
                    return
                }
                
                for values in categoryCode.values {
                    for value in values {
                        if value["category"] == intent.caption.lowercased().trimmingCharacters(in: .whitespaces) {
                            self.searchText = intent.caption
                            return
                        }
                    }
                }
            }
            self.placeResults = chatResults
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
        
        do {
            try chatHost.organizeCategoryCodeList()
        }catch {
            print(error)
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
        var radius = 2000
        var sort:String? = nil
        var limit:Int = 8
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
        if nearLocation == nil, let currentLocation = locationProvider.currentLocation(), locationProvider.queryLocation.coordinate.latitude == currentLocation.coordinate.latitude && locationProvider.queryLocation.coordinate.longitude == currentLocation.coordinate.longitude {
            let l = currentLocation
            ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
            
            print("Did not find a location in the query, using current location:\(String(describing: ll))")
        } else {
            if let delegate = assistiveHostDelegate {
                do {
                    if let placemarks = try await delegate.nearLocationCoordinate(for: intent.caption, tags: delegate.tags(for: intent.caption)), let location = placemarks.first?.location {
                        await MainActor.run {
                            locationProvider.queryLocation = location
                        }
                    }
                    
                    let l = locationProvider.queryLocation
                    ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
                } catch {
                    print(error)
                }
            }
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
                    let detailsResponse = try await PlaceResponseFormatter.placeDetailsResponse(with: rawDetailsResponse, for: response, previousDetails: strongSelf.assistiveHostDelegate?.queryIntentParameters.queryIntents.last?.placeDetailsResponses)
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
    public func didSearch(caption: String) async throws {
        guard caption.count > 0 else {
            resetPlaceModel()
            return
        }
        
        do {
            guard let chatHost = self.assistiveHostDelegate else {
                return
            }
            
            let intent:AssistiveChatHost.Intent = chatHost.determineIntent(for: caption)
            let queryParameters = try await chatHost.defaultParameters(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
            
            chatHost.updateLastIntentParameters(intent: newIntent)
            try await chatHost.receiveMessage(caption: caption, isLocalParticipant: true)
        } catch {
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
        try await chatHost.receiveMessage(caption: newIntent.caption, isLocalParticipant: true)
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
            print(error)
        }
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool) async throws {
        try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant)
        
        guard let lastIntent = queryParametersHistory.last?.queryIntents.last else {
            throw ChatResultViewModelError.MissingLastIntent
        }
        
        try await searchIntent(intent: lastIntent, location: locationProvider.queryLocation)
        try await didUpdateQuery(with: parameters)
    }
    
    public func didUpdateQuery(with parameters: AssistiveChatHostQueryParameters) async throws {
        try await refreshModel(queryIntents: parameters.queryIntents)
    }
    
}

extension ChatResultViewModel : AssistiveChatHostStreamResponseDelegate {
    public func willReceiveStreamingResult(for chatResultID: ChatResult.ID) async {
        fetchingPlaceID = chatResultID
        await MainActor.run {
            isFetchingPlaceDescription = true
        }
    }
    
    public func didFinishStreamingResult() async {
        fetchingPlaceID = nil
        await MainActor.run {
            isFetchingPlaceDescription = false
        }
    }
    
    public func didReceiveStreamingResult(with string: String, for result: ChatResult) async {
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
