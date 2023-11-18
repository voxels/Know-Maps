//
//  PlacesSearchSession.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import Foundation
import CloudKit
import NaturalLanguage

public enum PlaceSearchSessionError : Error {
    case ServiceNotFound
    case UnsupportedRequest
    case ServerErrorMessage
    case NoPlaceLocationsFound
}

open class PlaceSearchSession : ObservableObject {
    private var foursquareApiKey = ""
    private var searchSession:URLSession?
    let keysContainer = CKContainer(identifier:"iCloud.com.noisederived.No-Maps.Keys")
    static let serverUrl = "https://api.foursquare.com/"
    static let placeSearchAPIUrl = "v3/places/search"
    static let placeDetailsAPIUrl = "v3/places/"
    static let placePhotosAPIUrl = "/photos"
    static let placeTipsAPIUrl = "/tips"
    static let autocompleteAPIUrl = "v3/autocomplete"
    
    public enum PlaceSearchService : String {
        case foursquare
    }
    
    init(){
        
    }
    
    init(foursquareApiKey: String = "", foursquareSession: URLSession? = nil) {
        self.foursquareApiKey = foursquareApiKey
        self.searchSession = foursquareSession
        if let containerIdentifier = keysContainer.containerIdentifier {
            print(containerIdentifier)
        }
    }
    
    public func query(request:PlaceSearchRequest) async throws ->NSDictionary {
        if searchSession == nil {
            searchSession = try await session()
        }
        
        var components = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeSearchAPIUrl)")
        components?.queryItems = [URLQueryItem]()
        if request.query.count > 0 {
            let queryItem = URLQueryItem(name: "query", value: request.query)
            components?.queryItems?.append(queryItem)
        }
        
        if let nearLocation = request.nearLocation {
            let nearQueryItem = URLQueryItem(name: "near", value: nearLocation)
            components?.queryItems?.append(nearQueryItem)
        } else {
            let radiusQueryItem = URLQueryItem(name: "radius", value: "\(request.radius)")
            components?.queryItems?.append(radiusQueryItem)

            if let rawLocation = request.ll {
                let locationQueryItem = URLQueryItem(name: "ll", value: rawLocation)
                components?.queryItems?.append(locationQueryItem)
            }
        }
        
        if let categories = request.categories {
            let categoriesQueryItem = URLQueryItem(name:"categories", value:categories)
            components?.queryItems?.append(categoriesQueryItem)
        }
        
        if request.minPrice > 1 {
            let minPriceQueryItem = URLQueryItem(name: "min_price", value: "\(request.minPrice)")
            components?.queryItems?.append(minPriceQueryItem)
        }

        if request.maxPrice < 4 {
            let maxPriceQueryItem = URLQueryItem(name: "max_price", value: "\(request.maxPrice)")
            components?.queryItems?.append(maxPriceQueryItem)

        }
        
        if let openAt = request.openAt {
            let openAtQueryItem = URLQueryItem(name:"open_at", value:openAt)

            components?.queryItems?.append(openAtQueryItem)
        }
        
        if request.openNow == true {
            let openNowQueryItem = URLQueryItem(name: "open_now", value: "true")
            components?.queryItems?.append(openNowQueryItem)
        }
        

        
        if let sort = request.sort {
            let sortQueryItem = URLQueryItem(name: "sort", value: sort)
            components?.queryItems?.append(sortQueryItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(request.limit)")
        components?.queryItems?.append(limitQueryItem)
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let placeSearchResponse = try await fetch(url: url, apiKey: self.foursquareApiKey)
        
        guard let response = placeSearchResponse as? NSDictionary else {
            return NSDictionary()
        }
                
        return response
    }
    
    public func details(for request:PlaceDetailsRequest) async throws -> Any {
        if searchSession == nil {
            searchSession = try await session()
        }
        
        var components = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(request.fsqID)")
        var detailsString = ""
        
        if request.description{
            detailsString.append("description,")
        }
        if request.tel {
            detailsString.append("tel,")
        }
        if request.fax{
            detailsString.append("fax,")
        }
        if request.email{
            detailsString.append("email,")
        }
        if request.website{
            detailsString.append("website,")
        }
        if request.socialMedia{
            detailsString.append("social_media,")
        }
        if request.verified{
            detailsString.append("verified,")
        }
        if request.hours{
            detailsString.append("hours,")
        }
        if request.hoursPopular{
            detailsString.append("hours_popular,")
        }
        if request.rating{
            detailsString.append("rating,")
        }
        if request.stats{
            detailsString.append("stats,")
        }
        if request.popularity{
            detailsString.append("popularity,")
        }
        if request.price{
            detailsString.append("price,")
        }
        if request.menu{
            detailsString.append("menu,")
        }
        if request.dateClosed{
            detailsString.append("date_closed,")
        }
        if request.photos{
            detailsString.append("photos,")
        }
        if request.tips{
            detailsString.append("tips,")
        }
        if request.tastes{
            detailsString.append("tastes,")
        }
        if request.features{
            detailsString.append("features,")
        }
        if request.storeID{
            //detailsString.append("store_id")
        }
        
        if detailsString.hasSuffix(",") {
            detailsString.removeLast()
        }
        
        let queryItem = URLQueryItem(name: "fields", value:detailsString)
        components?.queryItems = [queryItem]
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url, apiKey: self.foursquareApiKey)
    }
    
    public func photos(for fsqID:String) async throws -> Any {
        if searchSession == nil {
            searchSession = try await session()
        }
        
        let components = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placePhotosAPIUrl)")
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url, apiKey: self.foursquareApiKey)
    }
    
    public func tips(for fsqID:String) async throws -> Any {
        if searchSession == nil {
            searchSession = try await session()
        }
        
        let components = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placeTipsAPIUrl)")
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url, apiKey: self.foursquareApiKey)
    }
    
    public func autocomplete(caption:String, parameters:[String:Any]?, currentLocation:CLLocationCoordinate2D) async throws -> NSDictionary {
        if searchSession == nil {
            searchSession = try await session()
        }
        
        let ll = "\(currentLocation.latitude),\(currentLocation.longitude)"
        var limit = 10
        var nameString:String = ""
        
        if let parameters = parameters, let rawQuery = parameters["query"] as? String {
            nameString = rawQuery
        } else {
            let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
            tagger.string = caption

            let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
            let tags: [NLTag] = [.personalName, .placeName, .organizationName, .noun, .adjective]


            tagger.enumerateTags(in: caption.startIndex..<caption.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, tokenRange in
                // Get the most likely tag, and print it if it's a named entity.
                if let tag = tag, tags.contains(tag) {
                    print("\(caption[tokenRange]): \(tag.rawValue)")
                    nameString.append("\(caption[tokenRange]) ")
                }
                    
                // Get multiple possible tags with their associated confidence scores.
                let (hypotheses, _) = tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: .nameTypeOrLexicalClass, maximumCount: 1)
                print(hypotheses)
                    
               return true
            }
        }
        
        if let parameters = parameters, let rawParameters = parameters["parameters"] as? NSDictionary {
            
            if let rawLimit = rawParameters["limit"] as? Int {
                limit = rawLimit
            }
        }
        
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.autocompleteAPIUrl)")
        queryComponents?.queryItems = [URLQueryItem]()

        if nameString.count > 0 {
            let queryUrlItem = URLQueryItem(name: "query", value: nameString.trimmingCharacters(in: .whitespacesAndNewlines))
            queryComponents?.queryItems?.append(queryUrlItem)
        } else {
            let queryUrlItem = URLQueryItem(name: "query", value: caption)
            queryComponents?.queryItems?.append(queryUrlItem)
        }
        
        if ll.count > 0 {
            let locationQueryItem = URLQueryItem(name: "ll", value: ll)
            queryComponents?.queryItems?.append(locationQueryItem)
            
            let radiusQueryItem = URLQueryItem(name: "radius", value: "2000")
            queryComponents?.queryItems?.append(radiusQueryItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(limit)")
        queryComponents?.queryItems?.append(limitQueryItem)
        
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let placeSearchResponse = try await fetch(url: url, apiKey: self.foursquareApiKey)
        
        guard let response = placeSearchResponse as? NSDictionary else {
            return NSDictionary()
        }
                
        return response
    }
    
    internal func location(near places:[PlaceSearchResponse]) throws ->CLLocationCoordinate2D {
        guard let firstPlace = places.first else {
            throw PlaceSearchSessionError.NoPlaceLocationsFound
        }
        
        let retval = CLLocationCoordinate2D(latitude: firstPlace.latitude, longitude: firstPlace.longitude)
        let coordinates = places.compactMap { place in
            return CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        }
        
        var minLatitude  = retval.latitude
        var minLongitude = retval.longitude
        var maxLatitude = retval.latitude
        var maxLongitude = retval.longitude
        
        for coordinate in coordinates {
            if coordinate.latitude < minLatitude {
                minLatitude = coordinate.latitude
            } else if coordinate.latitude > maxLatitude {
                maxLatitude = coordinate.latitude
            }
            
            if coordinate.longitude < minLongitude {
                minLongitude = coordinate.longitude
            } else if coordinate.longitude > maxLongitude {
                maxLongitude = coordinate.longitude
            }
        }

        let centerLatitude = (maxLatitude - minLatitude) / 2 + minLatitude
        let centerLongitude = (maxLongitude - minLongitude) / 2 + minLongitude
        return CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    
    internal func fetch(url:URL, apiKey:String) async throws -> Any {
        print("Requesting URL: \(url)")
        var request = URLRequest(url:url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let responseAny:Any = try await withCheckedThrowingContinuation({checkedContinuation in
            let dataTask = searchSession?.dataTask(with: request, completionHandler: { data, response, error in
                if let e = error {
                    print(e)
                    checkedContinuation.resume(throwing:e)
                } else {
                    if let d = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                            if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message.hasPrefix("Foursquare servers")  {
                                print("Message from server:")
                                print(message)
                                checkedContinuation.resume(throwing: PlaceSearchSessionError.ServerErrorMessage)
                            } else {
                                checkedContinuation.resume(returning:json)
                            }
                        } catch {
                            print(error)
                            let returnedString = String(data: d, encoding: String.Encoding.utf8) ?? ""
                            print(returnedString)
                            checkedContinuation.resume(returning: NSDictionary())                        }
                    }
                }
            })
            
            dataTask?.resume()
        })
        
        return responseAny
    }
    
    
    public func session(service:String = PlaceSearchService.foursquare.rawValue) async throws -> URLSession {
        let task = Task.init { () -> Bool in
            let predicate = NSPredicate(format: "service == %@", service)
            let query = CKQuery(recordType: "KeyString", predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["value", "service"]
            operation.resultsLimit = 1
            operation.recordMatchedBlock = { [weak self] recordId, result in
                guard let strongSelf = self else { return }

                do {
                    let record = try result.get()
                    if let apiKey = record["value"] as? String {
                        print("\(String(describing: record["service"]))")
                        print("Found API Key \(apiKey)")
                        strongSelf.foursquareApiKey = apiKey
                    } else {
                        print("Did not find API Key")
                    }
                } catch {
                    print(error)
                }
            }
            
            let success = try await withCheckedThrowingContinuation { checkedContinuation in
                operation.queryResultBlock = { result in
                    print(self.foursquareApiKey)
                    if self.foursquareApiKey == "" {
                        checkedContinuation.resume(with: .success(false))
                    } else {
                        checkedContinuation.resume(with: .success(true))
                    }
                }
                
                operation.queuePriority = .veryHigh
                operation.qualityOfService = .userInitiated
  
                keysContainer.publicCloudDatabase.add(operation)
            }
            
            return success
        }
        
        
        let foundApiKey = try await task.value
        if foundApiKey {
            switch PlaceSearchService(rawValue:service) {
            case .foursquare:
                return configuredSession()
            default:
                throw PlaceSearchSessionError.ServiceNotFound
            }
        } else {
            throw PlaceSearchSessionError.ServiceNotFound
        }
    }
}

private extension PlaceSearchSession {
    func configuredSession()->URLSession {
        let sessionConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfiguration)
        return session
    }
}
