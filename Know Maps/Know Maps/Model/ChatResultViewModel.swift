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
    private let maxChatResults:Int = 8
    
    private var queryCaption:String?
    private var queryParametersHistory = [AssistiveChatHostQueryParameters]()
    
    public var lastIntent:AssistiveChatHostIntent? {
        return queryParametersHistory.last?.queryIntents.last
    }
    
    public static let modelDefaults:[ChatResult] = [
        ChatResult(title: "Where can I find",   placeResponse: nil, placeDetailsResponse: nil),
        ChatResult(title: "Tell me about",  placeResponse: nil, placeDetailsResponse: nil),
    ]
    
    @Published public var results:[ChatResult]
    
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
    
    public func receiveMessage(caption: String, parameters: AssistiveChatHostQueryParameters, isLocalParticipant: Bool, nearLocation:CLLocation) async throws {
        queryCaption = caption
        queryParametersHistory.append(parameters)
        if isLocalParticipant {
            guard let lastIntent = lastIntent else {
                throw ChatResultViewModelError.MissingLastIntent
            }
            
            try await detailIntent(intent: lastIntent, nearLocation: nearLocation)
        } else {
            
        }
    }
    
    public func detailIntent( intent: AssistiveChatHostIntent, nearLocation:CLLocation) async throws {
        switch intent.intent {
        case .TellDefault, .SearchDefault, .Unsupported:
            break
        case .SearchQuery:
            let request = placeSearchRequest(intent: intent)
            let rawQueryResponse = try await placeSearchSession.query(request:request)
            let placeSearchResponses = try PlaceResponseFormatter.placeSearchResponses(with: rawQueryResponse, nearLocation: nearLocation)
            intent.placeSearchResponses = placeSearchResponses
            intent.placeDetailsResponses = try await fetchDetails(for: placeSearchResponses, nearLocation: nearLocation)
        case .TellPlace, .ShareResult:
            if let selectedPlaceSearchResponse = intent.selectedPlaceSearchResponse {
                intent.placeSearchResponses = [selectedPlaceSearchResponse]
                if let selectedPlaceDetailsResponse = intent.selectedPlaceSearchDetails {
                    intent.placeDetailsResponses = [selectedPlaceDetailsResponse]
                }
            } else {
                let autocompleteResponse = try await placeSearchSession.autocomplete(caption: intent.caption, parameters: intent.queryParameters, currentLocation:nearLocation.coordinate)
                let placeSearchResponses = try PlaceResponseFormatter.autocompletePlaceSearchResponses(with: autocompleteResponse, nearLocation:nearLocation)
                intent.placeSearchResponses = placeSearchResponses
                intent.placeDetailsResponses = try await fetchDetails(for: placeSearchResponses, nearLocation: nearLocation)
                
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
        case .SearchDefault:
            let chatResults = [ChatResult]()
            let blendedResults = blendDefaults(with: chatResults)
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                
                strongSelf.results.removeAll()
                strongSelf.results = blendedResults
                strongSelf.delegate?.didUpdateModel(for: strongSelf.locationProvider.currentLocation())
            }
        case .TellDefault:
            let _ = Task.init {
                let chatResults = [ChatResult]()
                let blendedResults = blendDefaults(with: chatResults)
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    
                    strongSelf.results.removeAll()
                    strongSelf.results = blendedResults
                    strongSelf.delegate?.didUpdateModel(for: strongSelf.locationProvider.currentLocation())
                    
                }
            }
        case .TellPlace:
            do {
                try tellQueryModel(intent: intent, nearLocation: nearLocation)
            } catch {
                print(error)
            }
        case .SearchQuery:
            searchQueryModel(intent: intent, nearLocation: nearLocation)
        default:
            break
        }
    }
    
    public func placeQueryModel(intent:AssistiveChatHostIntent) {
        let _ = Task.init {
            var chatResults = [ChatResult]()
            
            if let _ = intent.selectedPlaceSearchDetails {
                let allResponses = [PlaceDetailsResponse]()
                
                for index in 0..<min(allResponses.count,maxChatResults) {
                    
                    let response = allResponses[index]
                    let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response.searchResponse, details: response)
                    chatResults.append(contentsOf:results)
                }
            } else if let selectedPlaceResponse = intent.selectedPlaceSearchResponse {
                var allResponses = [PlaceSearchResponse]()
                
                allResponses.append(selectedPlaceResponse)
                
                for index in 0..<min(allResponses.count,maxChatResults) {
                    
                    let response = allResponses[index]
                    let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
                    chatResults.append(contentsOf:results)
                }
            } else if intent.placeSearchResponses.count > 0 {
                var allResponses = [PlaceSearchResponse]()
                
                allResponses.append(contentsOf: intent.placeSearchResponses)
                
                for index in 0..<min(allResponses.count,maxChatResults) {
                    
                    let response = allResponses[index]
                    let results = PlaceResponseFormatter.placeChatResults(for: intent, place: response, details: nil)
                    
                    chatResults.append(contentsOf:results)
                }
            }
            
            let blendedResults = blendDefaults(with: chatResults)
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                
                strongSelf.results.removeAll()
                strongSelf.results = blendedResults
                strongSelf.delegate?.didUpdateModel(for: strongSelf.locationProvider.currentLocation())
                
            }
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
            
            let blendedResults = blendDefaults(with: chatResults)
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                
                strongSelf.results.removeAll()
                strongSelf.results = blendedResults
                strongSelf.delegate?.didUpdateModel(for: strongSelf.locationProvider.currentLocation())
            }
    }
    
    public func tellQueryModel(intent:AssistiveChatHostIntent, nearLocation:CLLocation) throws {
        var chatResults = [ChatResult]()
        
        guard let placeResponse = intent.selectedPlaceSearchResponse, let detailsResponse = intent.selectedPlaceSearchDetails, let photosResponses = detailsResponse.photoResponses, let tipsResponses = detailsResponse.tipsResponses else {
            throw ChatResultViewModelError.MissingSelectedPlaceDetailsResponse
        }
        
        let results = PlaceResponseFormatter.placeDetailsChatResults(for: placeResponse, details:detailsResponse, photos: photosResponses, tips: tipsResponses, results: [placeResponse])
        chatResults.append(contentsOf:results)
        
        let blendedResults = blendDefaults(with: chatResults)
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.results.removeAll()
            strongSelf.results = blendedResults
            strongSelf.delegate?.didUpdateModel(for: strongSelf.locationProvider.currentLocation())
        }
    }
    
    public func zeroStateModel() {
        let blendedResults = blendDefaults(with: [])
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.results.removeAll()
            strongSelf.results = blendedResults
        }
    }
    
    private func blendDefaults(with chatResults:[ChatResult])->[ChatResult] {
        let defaultResults = categoricalResults()
        
        if let intent = lastIntent {
            var results = [ChatResult]()
            var defaults = ChatResultViewModel.modelDefaults
            switch intent.intent {
            case .SearchDefault:
                defaults.remove(at: 0)
                results.append(contentsOf: defaults)
                return results
            case  .TellDefault:
                defaults.remove(at: 0)
                results.append(contentsOf: defaults)
                return results
            case .SearchQuery:
                if let first = defaultResults.first {
                    results.append(first)
                }
                results.append(contentsOf:chatResults)
                if let last = defaultResults.last, last != defaultResults.first {
                    results.append(last)
                }
                return results
            case .TellPlace:
                results.append(contentsOf:chatResults)
                results.append(contentsOf:defaults)
                return results
            default:
                results.append(contentsOf: defaults)
                return results
            }
        } else {
            return defaultResults
        }
    }
    
    private func categoricalResults()->[ChatResult] {
        guard let unsortedKeys = assistiveHostDelegate?.categoryCodes.keys else {
            return ChatResultViewModel.modelDefaults
        }
        
        let sortedKeys = unsortedKeys.sorted()
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
            
            /*
             if let rawCategories = rawParameters["categories"] as? [NSDictionary] {
             for rawCategory in rawCategories {
             if let categoryName = rawCategory["name"] as? String {
             //query.append("\(categoryName) ")
             }
             }
             }
             */
            
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
        
        let request = PlaceSearchRequest(query:query, ll: ll, radius:radius, categories: nil, fields: nil, minPrice: minPrice, maxPrice: maxPrice, openAt: openAt, openNow: openNow, nearLocation: nearLocation, sort: sort, limit:limit)
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
