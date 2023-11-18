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
    case MissingSelectedPlaceSearchResponse
    case MissingSelectedPlaceDetailsResponse
    case NoAutocompleteResultsFound
}

public protocol ChatResultViewModelDelegate : AnyObject {
    func didUpdateModel(for location:CLLocation?)
}

public class ChatResultViewModel : ObservableObject {
    public weak var delegate:ChatResultViewModelDelegate?
    public weak var assistiveHostDelegate:AssistiveChatHostDelegate?
    private let placeSearchSession:PlaceSearchSession = PlaceSearchSession()
    public var locationProvider:LocationProvider
    private let maxChatResults:Int = 20
    
    private var queryCaption:String?
    private var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    
    public var lastIntent:AssistiveChatHostIntent? {
        return queryParametersHistory.last?.queryIntents.last
    }
    
    public static let modelDefaults:[ChatResult] = [
        ChatResult(title: "Where can I find",   placeResponse: nil, placeDetailsResponse: nil),
        ChatResult(title: "Tell me about",  placeResponse: nil, placeDetailsResponse: nil),
    ]
    
    @Published public var searchText: String = ""
    @Published public var results:[ChatResult]
    @Published public var placeResults:[ChatResult] = [ChatResult]()
    @Published public var selectedPlaceResult:ChatResult?
    
    public var filteredResults:[ChatResult] {
        get {
            guard !searchText.isEmpty else {
                return results
            }
            var filtered = results.filter { result in
                result.title.lowercased().contains(searchText.lowercased())
            }
            
            var remaining = results
            remaining.removeAll { result in
                result.title.lowercased().contains(searchText.lowercased())
            }
            
            filtered.append(contentsOf:remaining)
            return filtered
        }
    }
    
    public var filteredPlaceResults:[ChatResult] {
        get {
            let filtered = placeResults.filter { result in
                guard let details = result.placeDetailsResponse else {
                    return false
                }
                
                if let tipsResponses = details.tipsResponses, tipsResponses.count > 0 {
                    return true
                }
                
                if let tastes = details.tastes, tastes.count > 0 {
                    return true
                }
                
                if details.description != nil {
                    return true
                }
                
                if details.website != nil {
                    return true
                }
                
                return false
            }
            
            if filtered.isEmpty && placeResults.isEmpty {
                return [ChatResult(title: "No results nearby", placeResponse: nil, placeDetailsResponse: nil)]
            }
            
            return filtered.count == 0 ? placeResults : filtered
        }
    }
        
    public init(delegate: ChatResultViewModelDelegate? = nil, assistiveHostDelegate: AssistiveChatHostDelegate? = nil, locationProvider: LocationProvider, queryCaption: String? = nil, queryParametersHistory: [AssistiveChatHostQueryParameters] = [AssistiveChatHostQueryParameters](), results: [ChatResult]) {
        self.delegate = delegate
        self.assistiveHostDelegate = assistiveHostDelegate
        self.locationProvider = locationProvider
        self.queryCaption = queryCaption
        self.queryParametersHistory = queryParametersHistory
        self.results = results
    }
    
    public func authorizeLocationProvider() {
        locationProvider.authorize()
    }
    
    public func resetPlaceModel() {
        DispatchQueue.main.async {
            self.placeResults = [ChatResult]()
        }
    }
    
    public func chatResult(for selectedChatResultID:ChatResult.ID)->ChatResult{
        let selectedResult = filteredResults.first(where: { checkResult in
            return checkResult.id == selectedChatResultID
        })
        
        guard let selectedResult = selectedResult else {
            return ChatResult(title: "Not found", placeResponse: nil, placeDetailsResponse: nil)
        }
        
        return selectedResult
    }
    
    public func chatResult(title:String)->ChatResult {
        let selectedResult = filteredResults.first(where: { checkResult in
            return checkResult.title.lowercased().trimmingCharacters(in: .whitespaces) == title.lowercased().trimmingCharacters(in: .whitespaces)
        })
        
        guard let selectedResult = selectedResult else {
            return ChatResult(title: title, placeResponse: nil, placeDetailsResponse: nil)
        }
        
        return selectedResult
    }
    
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, nearLocation:CLLocation) async throws {
        self.queryCaption = caption
        self.queryParametersHistory.append(parameters)
        if isLocalParticipant {
            guard let lastIntent = self.lastIntent else {
                throw ChatResultViewModelError.MissingLastIntent
            }
            
            try await self.detailIntent(intent: lastIntent, nearLocation: nearLocation)
        } else {
            
        }
    }
    
    public func detailIntent( intent: AssistiveChatHostIntent, nearLocation:CLLocation) async throws {
        switch intent.intent {
        case .TellDefault, .SearchDefault:
            break
        case .SearchQuery:
            let request = placeSearchRequest(intent: intent)
            let rawQueryResponse = try await placeSearchSession.query(request:request)
            let placeSearchResponses = try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse, nearLocation: nearLocation)
            intent.placeSearchResponses = placeSearchResponses
            if placeSearchResponses.count > 0 {
                intent.placeDetailsResponses = try await fetchDetails(for: placeSearchResponses, nearLocation: nearLocation)
            }
        case .TellPlace, .ShareResult, .Unsupported:
            if let selectedPlaceSearchResponse = intent.selectedPlaceSearchResponse {
                intent.placeSearchResponses = [selectedPlaceSearchResponse]
                if let selectedPlaceDetailsResponse = intent.selectedPlaceSearchDetails {
                    intent.placeDetailsResponses = [selectedPlaceDetailsResponse]
                }
            } else {
                let autocompleteResponse = try await placeSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, currentLocation:nearLocation.coordinate)
                let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse, nearLocation:nearLocation)
                intent.placeSearchResponses = placeSearchResponses
                if placeSearchResponses.count > 0 {
                    intent.placeDetailsResponses = try await fetchDetails(for: placeSearchResponses, nearLocation: nearLocation)
                }
                
                if let detailsResponses = intent.placeDetailsResponses {
                    if detailsResponses.count >= 1, let firstDetailsResponse = detailsResponses.first {
                        intent.selectedPlaceSearchResponse = firstDetailsResponse.searchResponse
                        intent.selectedPlaceSearchDetails = firstDetailsResponse
                    } else  {
                        throw ChatResultViewModelError.NoAutocompleteResultsFound
                    }
                }
            }
        }
    }
    
    
    
    public func refreshModel(queryIntents:[AssistiveChatHostIntent]? = nil, nearLocation:CLLocation) {
        guard let queryIntents = queryIntents else {
            zeroStateModel()
            return
        }
        
        switch queryIntents.count {
        case 0:
            zeroStateModel()
        default:
            if let lastIntent = queryIntents.last {
                model(intent:lastIntent, nearLocation: nearLocation)
            } else {
                zeroStateModel()
            }
        }
    }
    
    public func model(intent:AssistiveChatHostIntent, nearLocation:CLLocation) {
        switch intent.intent {
        case .TellPlace:
            do {
                try tellQueryModel(intent: intent, nearLocation: nearLocation)
            } catch {
                print(error)
            }
        default:
            searchQueryModel(intent: intent, nearLocation: nearLocation)
        }
    }
    
    
    public func searchQueryModel(intent:AssistiveChatHostIntent, nearLocation:CLLocation ) {
        var chatResults = [ChatResult]()
        if let allResponses = intent.placeDetailsResponses {
            for index in 0..<min(allResponses.count,maxChatResults) {
                let response = allResponses[index]
                
                let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response.searchResponse, details: response)
                chatResults.append(contentsOf:results)
            }
        }
        
        DispatchQueue.main.async {
            self.placeResults = chatResults
        }
    }
    
    public func tellQueryModel(intent:AssistiveChatHostIntent, nearLocation:CLLocation) throws {
        var chatResults = [ChatResult]()
        
        guard let placeResponse = intent.selectedPlaceSearchResponse, let detailsResponse = intent.selectedPlaceSearchDetails, let photosResponses = detailsResponse.photoResponses, let tipsResponses = detailsResponse.tipsResponses else {
            throw ChatResultViewModelError.MissingSelectedPlaceDetailsResponse
        }
        
        let results = PlaceResponseFormatter.placeDetailsChatResults(for: placeResponse, details:detailsResponse, photos: photosResponses, tips: tipsResponses, results: [placeResponse])
        chatResults.append(contentsOf:results)
        
        DispatchQueue.main.async {
            self.placeResults = chatResults
        }

    }
    
    public func zeroStateModel() {
        let blendedResults = categoricalResults()
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.results.removeAll()
            strongSelf.results = blendedResults
        }
    }
        
    private func categoricalResults()->[ChatResult] {
        guard let unsortedKeys = assistiveHostDelegate?.categoryCodes.keys else {
            return ChatResultViewModel.modelDefaults
        }
        
        var sortedKeys = unsortedKeys.sorted()
        let bannedList = ["adult store"]
        sortedKeys.removeAll { category in
            bannedList.contains(category)
        }
        let results = sortedKeys.map { category in
            return ChatResult(title:category, placeResponse: nil, placeDetailsResponse: nil)
        }
        return results
    }
    
    
    private func placeSearchRequest(intent:AssistiveChatHostIntent)->PlaceSearchRequest {
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
            
            if let rawNear = rawParameters["near"] as? [String], let firstNear = rawNear.first, firstNear.count > 0 {
                nearLocation = rawNear.first
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
        if nearLocation == nil {
            let location = locationProvider.currentLocation()
            if let l = location {
                ll = "\(l.coordinate.latitude),\(l.coordinate.longitude)"
            }
            
            print("Did not find a location in the query, using current location:\(String(describing: ll))")
        }
        
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = PlaceSearchRequest(query:query, ll: ll, radius:radius, categories: categories, fields: nil, minPrice: minPrice, maxPrice: maxPrice, openAt: openAt, openNow: openNow, nearLocation: nearLocation, sort: sort, limit:limit)
        return request
    }
    
    internal func fetchDetails(for responses:[PlaceSearchResponse], nearLocation:CLLocation) async throws -> [PlaceDetailsResponse] {
        let placeDetailsResponses = try await withThrowingTaskGroup(of: PlaceDetailsResponse.self, returning: [PlaceDetailsResponse].self) { [weak self] taskGroup in
            guard let strongSelf = self else {
                return [PlaceDetailsResponse]()
            }
            for index in 0..<(min(responses.count, strongSelf.maxChatResults)) {
                taskGroup.addTask {
                    let response = responses[index]
                    let request = PlaceDetailsRequest(fsqID: response.fsqID, description: true, tel: true, fax: false, email: false, website: true, socialMedia: true, verified: false, hours: true, hoursPopular: true, rating: true, stats: false, popularity: true, price: true, menu: true, tastes: true, features: false)
                    print("Fetching details for \(response.name)")
                    let rawDetailsResponse = try await strongSelf.placeSearchSession.details(for: request)
                    let detailsResponse = try PlaceResponseFormatter.placeDetailsResponse(with: rawDetailsResponse, for: response)
                    return detailsResponse
                }
            }
            var allResponses = [PlaceDetailsResponse]()
            for try await value in taskGroup {
                allResponses.append(value)
            }
            
            allResponses = allResponses.sorted(by: { firstResponse, checkResponse in
                let firstLocation = CLLocation(latitude: firstResponse.searchResponse.latitude, longitude: firstResponse.searchResponse.longitude)
                let checkLocation = CLLocation(latitude: checkResponse.searchResponse.latitude, longitude: checkResponse.searchResponse.longitude)
                return firstLocation.distance(from: nearLocation) < checkLocation.distance(from: nearLocation)
            })
            return allResponses
        }
        
        return placeDetailsResponses
    }
    
}

extension ChatResultViewModel : AssistiveChatHostMessagesDelegate {
    public func didTap(chatResult: ChatResult, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?) {
        guard chatResult.title.count > 0 else {
            resetPlaceModel()
            return
        }
        
        let _ = Task.init {
            do {
                guard let chatHost = self.assistiveHostDelegate else {
                    return
                }
                
                let caption = chatResult.title
                let intent = try chatHost.determineIntent(for: caption, placeSearchResponse: selectedPlaceSearchResponse)
                let queryParameters = try await chatHost.defaultParameters(for: caption)
                let newIntent = AssistiveChatHostIntent(caption: caption, intent: intent, selectedPlaceSearchResponse: selectedPlaceSearchResponse, selectedPlaceSearchDetails: selectedPlaceSearchDetails, placeSearchResponses: [PlaceSearchResponse](), placeDetailsResponses:nil, queryParameters: queryParameters)
                chatHost.appendIntentParameters(intent: newIntent)
                if let location = locationProvider.currentLocation() {
                    try await chatHost.receiveMessage(caption: caption, isLocalParticipant: true, nearLocation: location)
                }
            } catch {
                print(error)
            }
        }
    }
    
    public func addReceivedMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, nearLocation: CLLocation) async throws {
        try await receiveMessage(caption: caption, parameters: parameters, isLocalParticipant: isLocalParticipant, nearLocation: nearLocation)
    }
    
    public func didUpdateQuery(with parameters: AssistiveChatHostQueryParameters, nearLocation: CLLocation) {
        refreshModel(queryIntents: parameters.queryIntents, nearLocation: nearLocation )
    }
    
}

extension ChatResultViewModel : AssistiveChatHostStreamResponseDelegate {
    public func didReceiveStreamingResult(with string: String, for result: ChatResult) {
        let candidates = placeResults.filter { checkResult in
            return checkResult.placeResponse?.fsqID != nil && checkResult.placeResponse?.fsqID == result.placeResponse?.fsqID
        }
        
        guard let firstCandidate = candidates.first else {
            return
        }
        
        
        if let placeDetailsResponse = firstCandidate.placeDetailsResponse {
            let newDetailsResponse = PlaceDetailsResponse(searchResponse: placeDetailsResponse.searchResponse, photoResponses: placeDetailsResponse.photoResponses, tipsResponses: placeDetailsResponse.tipsResponses, description: (placeDetailsResponse.description ?? "").appending(string), tel: placeDetailsResponse.tel, fax: placeDetailsResponse.fax, email: placeDetailsResponse.email, website: placeDetailsResponse.website, socialMedia: placeDetailsResponse.socialMedia, verified: placeDetailsResponse.verified, hours: placeDetailsResponse.hours, openNow: placeDetailsResponse.openNow, hoursPopular:placeDetailsResponse.hoursPopular, rating: placeDetailsResponse.rating, stats: placeDetailsResponse.stats, popularity: placeDetailsResponse.popularity, price: placeDetailsResponse.price, menu: placeDetailsResponse.menu, dateClosed: placeDetailsResponse.dateClosed, tastes: placeDetailsResponse.tastes, features: placeDetailsResponse.features)
            var newPlaceResults = [ChatResult]()
            let fsqID = newDetailsResponse.fsqID
            for placeResult in self.placeResults {
                if placeResult.placeResponse?.fsqID == fsqID {
                    newPlaceResults.append(ChatResult(title: result.title, placeResponse: newDetailsResponse.searchResponse, placeDetailsResponse: newDetailsResponse))
                } else {
                    newPlaceResults.append(placeResult)
                }
            }
            
            DispatchQueue.main.sync {
                self.placeResults = newPlaceResults
            }
        }
    }
}
