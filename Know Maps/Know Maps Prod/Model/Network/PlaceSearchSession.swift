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
    case InvalidSession
}

public actor PlaceSearchSession : ObservableObject {
    private var foursquareApiKey = ""
    private var searchSession:URLSession?
    let keysContainer = CKContainer(identifier:"iCloud.com.secretatomics.knowmaps.Keys")
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
    
    public func query(request:PlaceSearchRequest, location:CLLocation?) async throws ->[String:Any] {
        var components = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeSearchAPIUrl)")
        var queryItems = [URLQueryItem]()
        if request.query.count > 0 {
            let queryItem = URLQueryItem(name: "query", value: request.query)
            queryItems.append(queryItem)
        }
        
        if let location = location, request.nearLocation == nil {
            let rawLocation = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            let radius = request.radius
            let radiusQueryItem = URLQueryItem(name: "radius", value: "\(radius)")
            queryItems.append(radiusQueryItem)
            
            let locationQueryItem = URLQueryItem(name: "ll", value: rawLocation)
            queryItems.append(locationQueryItem)
        } else {
            var value = request.radius
            if let nearLocation = request.nearLocation, !nearLocation.isEmpty {
                value = 25000
            }
            let radiusQueryItem = URLQueryItem(name: "radius", value: "\(value)")
            queryItems.append(radiusQueryItem)

            if let rawLocation = request.ll {
                let locationQueryItem = URLQueryItem(name: "ll", value: rawLocation)
                queryItems.append(locationQueryItem)
            }
        }
        
        if let categories = request.categories, !categories.isEmpty {
            let categoriesQueryItem = URLQueryItem(name:"categories", value:categories)
            queryItems.append(categoriesQueryItem)
        }
        
        if request.minPrice > 1 {
            let minPriceQueryItem = URLQueryItem(name: "min_price", value: "\(request.minPrice)")
            queryItems.append(minPriceQueryItem)
        }

        if request.maxPrice < 4 {
            let maxPriceQueryItem = URLQueryItem(name: "max_price", value: "\(request.maxPrice)")
            queryItems.append(maxPriceQueryItem)

        }
        
        if let openAt = request.openAt {
            let openAtQueryItem = URLQueryItem(name:"open_at", value:openAt)

            queryItems.append(openAtQueryItem)
        }
        
        if request.openNow == true {
            let openNowQueryItem = URLQueryItem(name: "open_now", value: "true")
            queryItems.append(openNowQueryItem)
        }
        

        
        if let sort = request.sort {
            let sortQueryItem = URLQueryItem(name: "sort", value: sort)
            queryItems.append(sortQueryItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(request.limit)")
        queryItems.append(limitQueryItem)
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let placeSearchResponse = try await fetch(url: url)
        
        guard let response = placeSearchResponse as? [String:Any] else {
            return [String:Any]()
        }
                
        return response
    }
    
    public func details(for request:PlaceDetailsRequest) async throws -> Any {
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
        
        if request.core {
            detailsString.append("fsq_id,name,geocodes,location,categories,chains,related_places,timezone,distance,link,")
        }
        
        if detailsString.hasSuffix(",") {
            detailsString.removeLast()
        }
        
        let queryItem = URLQueryItem(name: "fields", value:detailsString)
        components?.queryItems = [queryItem]
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        
        return try await fetch(url: url)
    }
    
    public func photos(for fsqID:String) async throws -> Any {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placePhotosAPIUrl)")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(50)")
        let sortQueryItem = URLQueryItem(name:"sort", value:"newest")
        queryComponents?.queryItems = [limitQueryItem, sortQueryItem]
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url)
    }
    
    public func tips(for fsqID:String) async throws -> Any {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placeTipsAPIUrl)")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(50)")
        let queryItems = [limitQueryItem]
        queryComponents?.queryItems = queryItems

        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url)
    }
    
    public func autocomplete(caption:String, parameters:[String:Any]?, location:CLLocation) async throws -> [String:Any] {
        let ll = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        var limit = 50
        
        if let parameters = parameters, let rawParameters = parameters["parameters"] as? NSDictionary {
            
            if let rawLimit = rawParameters["limit"] as? Int {
                limit = rawLimit
            }
            
            
        }
        
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.autocompleteAPIUrl)")
        var queryItems = [URLQueryItem]()

        let queryUrlItem = URLQueryItem(name: "query", value: caption)
        queryItems.append(queryUrlItem)
        
        if ll.count > 0 {
            let locationQueryItem = URLQueryItem(name: "ll", value: ll)
            queryItems.append(locationQueryItem)
            
            let value = 50000
            let radiusQueryItem = URLQueryItem(name: "radius", value:"\(value)")
            queryItems.append(radiusQueryItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(limit)")
        queryItems.append(limitQueryItem)

        let placeQueryItem = URLQueryItem(name: "types", value: "place")
        queryItems.append(placeQueryItem)
        
        queryComponents?.queryItems = queryItems

        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let placeSearchResponse = try await fetch(url: url)
        
        guard let response = placeSearchResponse as? [String:Any] else {
            return [String:Any]()
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
    
    
    private let sessionQueue = DispatchQueue(label: "com.secretatomics.knowmaps.sessionQueue")

    func fetch(url: URL) async throws -> Any {
        print("Requesting URL: \(url)")

        if searchSession == nil {
            searchSession = try await session()
        }

        return try await withCheckedThrowingContinuation { checkedContinuation in
            let apiKey = foursquareApiKey
            guard let session = searchSession else {
                return
            }
            sessionQueue.async {
                var request = URLRequest(url: url)
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
                session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        checkedContinuation.resume(throwing: error)
                    } else if let d = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                            if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message.hasPrefix("Foursquare servers")  {
                                print("Message from server:")
                                print(message)
                                checkedContinuation.resume(throwing: PlaceSearchSessionError.ServerErrorMessage)
                            } else if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message == "Invalid request token." {
                                checkedContinuation.resume(throwing: PlaceSearchSessionError.InvalidSession)
                            } else {
                                checkedContinuation.resume(returning:json)
                            }
                        } catch {
                            print(error)
                            let returnedString = String(data: d, encoding: String.Encoding.utf8) ?? ""
                            print(returnedString)
                            checkedContinuation.resume(throwing: PlaceSearchSessionError.ServerErrorMessage)
                        }
                    }
                }.resume()
            }
        }
    }
    
    public func invalidateSession() async throws {
        try await deleteAPIKeyRecords()
        searchSession = nil
        searchSession = try await session()
    }

    func deleteAPIKeyRecords(service:String = PlaceSearchService.foursquare.rawValue) async throws {
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "service == %@", service)
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        
        var recordIDsToDelete: [CKRecord.ID] = []
        
        operation.recordMatchedBlock = { record, error in
            recordIDsToDelete.append(record)
        }
                
        database.add(operation)
        
        if !recordIDsToDelete.isEmpty {
            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
            database.add(deleteOperation)
        }
    }
    
    public func session(service: String = PlaceSearchService.foursquare.rawValue) async throws -> URLSession {
        let predicate = NSPredicate(format: "service == %@", service)
        let query = CKQuery(recordType: "KeyString", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["value", "service"]
        operation.resultsLimit = 1

        operation.recordMatchedBlock = { [weak self] recordId, result in
            Task { [weak self] in
                guard let self = self else { return }
                await self.handleRecordMatched(result: result)
            }
        }

        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated

        let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            operation.queryResultBlock = { [weak self] result in
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.handleQueryResult(result: result, continuation: continuation)
                }
            }

            keysContainer.publicCloudDatabase.add(operation)
        }

        if success {
            return configuredSession()
        } else {
            throw PlaceSearchSessionError.ServiceNotFound
        }
    }
    
    private func handleRecordMatched(result: Result<CKRecord, Error>) async {
        do {
            let record = try result.get()
            if let apiKey = record["value"] as? String {
                print("\(String(describing: record["service"]))")
                // Now safely modify the actor-isolated property
                self.foursquareApiKey = apiKey
            } else {
                print("Did not find API Key")
            }
        } catch {
            print(error)
        }
    }
    
    private func handleQueryResult(result: Result<CKQueryOperation.Cursor?, Error>, continuation: CheckedContinuation<Bool, Error>) async {
        switch result {
        case .success(_):
            continuation.resume(returning: true)
        case .failure(let error):
            print(error)
            continuation.resume(returning: false)
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
