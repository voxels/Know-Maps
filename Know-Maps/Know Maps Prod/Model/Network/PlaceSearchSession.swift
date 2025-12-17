//
//  PlacesSearchSession.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import Foundation
import CloudKit
import NaturalLanguage
import Combine
import CoreLocation
import ConcurrencyExtras

public enum PlaceSearchSessionError : Error {
    case ServiceNotFound
    case UnsupportedRequest
    case ServerErrorMessage
    case NoPlaceLocationsFound
    case InvalidSession
}

public actor PlaceSearchSession : ObservableObject {
    private var foursquareApiKey = ""
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
    
    init(foursquareApiKey: String = "") {
        self.foursquareApiKey = foursquareApiKey
        if let containerIdentifier = keysContainer.containerIdentifier {
            print(containerIdentifier)
        }
    }
    
    @MainActor
    public func query(request:PlaceSearchRequest) async throws ->[String:[Dictionary<String, String>]] {
        var components = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeSearchAPIUrl)")
        var queryItems = [URLQueryItem]()
        if request.query.count > 0 {
            let queryItem = URLQueryItem(name: "query", value: request.query)
            queryItems.append(queryItem)
        }
        
        var value = request.radius
        if let nearLocation = request.nearLocation, !nearLocation.isEmpty {
            // When using "near", cap radius to a sane upper bound supported by FSQ (100km)
            value = min(value, 100000)
        }

        if let nearLocation = request.nearLocation, !nearLocation.isEmpty {
            // Remote/city-biased search
            queryItems.append(URLQueryItem(name: "near", value: nearLocation))
        } else if let rawLocation = request.ll {
            // Local/GPS-biased search
            queryItems.append(URLQueryItem(name: "ll", value: rawLocation))
            queryItems.append(URLQueryItem(name: "radius", value: "\(value)"))
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
        
        guard let response = placeSearchResponse as? [String:[Dictionary<String, String>]] else {
            return [String:[Dictionary<String, String>]]()
        }
                
        return response
    }
    
    public func details(for request:PlaceDetailsRequest) async throws -> String {
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
    
    public func photos(for fsqID:String) async throws -> String {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placePhotosAPIUrl)")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(50)")
        let sortQueryItem = URLQueryItem(name:"sort", value:"newest")
        queryComponents?.queryItems = [limitQueryItem, sortQueryItem]
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url)
    }
    
    public func tips(for fsqID:String) async throws -> String {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placeTipsAPIUrl)")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(50)")
        let queryItems = [limitQueryItem]
        queryComponents?.queryItems = queryItems

        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        return try await fetch(url: url)
    }
    
    public func autocomplete(caption: String, limit: Int?, locationResult: LocationResult) async throws -> Dictionary<String, String> {
        let ll = "\(locationResult.location.coordinate.latitude),\(locationResult.location.coordinate.longitude)"
        var resolvedLimit = 50
        if let limit = limit {
            resolvedLimit = limit
        }

        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.autocompleteAPIUrl)")
        var queryItems = [URLQueryItem]()

        let queryUrlItem = URLQueryItem(name: "query", value: caption)
        queryItems.append(queryUrlItem)

        if ll.count > 0 {
            let locationQueryItem = URLQueryItem(name: "ll", value: ll)
            queryItems.append(locationQueryItem)

            let radiusItem = URLQueryItem(name: "radius", value: "\(100000)")
            queryItems.append(radiusItem)
        }

        let limitQueryItem = URLQueryItem(name: "limit", value: "\(resolvedLimit)")
        queryItems.append(limitQueryItem)

        queryComponents?.queryItems = queryItems

        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }

        let placeSearchResponse = try await fetch(url: url)

        if let response = placeSearchResponse as? Dictionary<String,String> {
            return response
        } else if let dict = placeSearchResponse as? [String: String] {
            return dict
        } else {
            return [:]
        }
    }

    private func splitQueryAndNear(_ caption: String) -> (poi: String, near: String?) {
        let parts = caption.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            let poi = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let near = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return (poi, near.isEmpty ? nil : near)
        } else {
            return (caption, nil)
        }
    }
    
    private func placeSearchForAutocomplete(caption: String, locationResult: LocationResult) async throws -> Any {
        let (poiQuery, nearBias) = splitQueryAndNear(caption)

        var llParam: String? = nil
        var nearParam: String? = nil

        if let nearBias = nearBias, !nearBias.isEmpty {
            // User specified a remote locality; prefer `near`
            nearParam = nearBias
        } else {
            // Fall back to local coordinates
            let coord = locationResult.location.coordinate
            llParam = "\(coord.latitude),\(coord.longitude)"
        }

        let request = PlaceSearchRequest(
            query: poiQuery,
            ll: llParam,
            radius: 100000,
            categories: nil,
            fields: nil,
            minPrice: 1,
            maxPrice: 4,
            openAt: nil,
            openNow: nil,
            nearLocation: nearParam,
            sort: nil,
            limit: 20,
            offset: 0
        )
        return try await self.query(request: request)
    }
    
    private func parseAutocompleteToLocationResults(_ response: [String: Any]) -> [LocationResult] {
        var results: [LocationResult] = []

        // Autocomplete response uses a top-level "results" array
        guard let items = response["results"] as? [[String: Any]] else {
            return results
        }

        for item in items {
            guard let type = item["type"] as? String else { continue }

            switch type {
            case "place":
                // According to docs, place details are under the `place` key
                guard let place = item["place"] as? [String: Any] else { continue }
                let name = (place["name"] as? String) ?? "Unknown"
                let locationDict = place["location"] as? [String: Any]
                let formatted = locationDict?["formatted_address"] as? String

                var lat: Double?
                var lon: Double?
                if let geocodes = place["geocodes"] as? [String: Any] {
                    if let main = geocodes["main"] as? [String: Any] {
                        lat = main["latitude"] as? Double
                        lon = main["longitude"] as? Double
                    }
                    if lat == nil || lon == nil, let roof = geocodes["roof"] as? [String: Any] {
                        lat = roof["latitude"] as? Double
                        lon = roof["longitude"] as? Double
                    }
                }

                if let lat = lat, let lon = lon {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let lr = LocationResult(locationName: name, location: loc, formattedAddress: formatted)
                    results.append(lr)
                }

            case "address":
                // Address details are under `address` key in docs
                let text = (item["text"] as? String) ?? (item["name"] as? String) ?? "Address"
                let formatted = item["formatted_address"] as? String ?? item["address"] as? String

                var lat: Double?
                var lon: Double?
                if let geocodes = item["geocodes"] as? [String: Any],
                   let main = geocodes["main"] as? [String: Any] {
                    lat = main["latitude"] as? Double
                    lon = main["longitude"] as? Double
                }
                if (lat == nil || lon == nil), let center = item["center"] as? [String: Any] {
                    lat = center["latitude"] as? Double
                    lon = center["longitude"] as? Double
                }

                if let lat = lat, let lon = lon {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let lr = LocationResult(locationName: text, location: loc, formattedAddress: formatted)
                    results.append(lr)
                }

            case "geo":
                // Geo items expose a `text` label and a `center` or `geocodes.main`
                let text = (item["text"] as? String) ?? (item["name"] as? String) ?? "Area"

                var lat: Double?
                var lon: Double?
                if let center = item["center"] as? [String: Any] {
                    lat = center["latitude"] as? Double
                    lon = center["longitude"] as? Double
                }
                if (lat == nil || lon == nil), let geocodes = item["geocodes"] as? [String: Any],
                   let main = geocodes["main"] as? [String: Any] {
                    lat = main["latitude"] as? Double
                    lon = main["longitude"] as? Double
                }

                if let lat = lat, let lon = lon {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let lr = LocationResult(locationName: text, location: loc)
                    results.append(lr)
                }

            default:
                continue
            }
        }

        return results
    }

    private func resolveCoordinateForNear(_ near: String) async throws -> CLLocationCoordinate2D? {
        // Build a lightweight request that asks FSQ to bias by `near` and return a single result
        let request = PlaceSearchRequest(
            query: "",
            ll: nil,
            radius: 100000,
            categories: nil,
            fields: nil,
            minPrice: 1,
            maxPrice: 4,
            openAt: nil,
            openNow: nil,
            nearLocation: near,
            sort: nil,
            limit: 1,
            offset: 0
        )
        let any = try? await self.query(request: request)
        guard let dict = any,
              let items = dict["results"] as? [[String: String]],
              let first = items.first,
              let geocodes = first["geocodes"] as? [String: String],
              let main = geocodes["main"] as? [String: String],
              let lat = Double(main["latitude"] as? String ?? "37.333562"),
              let lon = Double(main["longitude"] as? String ?? "-122.004927") else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    public func autocompleteLocationResults(caption: String, parameters: [String: Any]?, locationResult: LocationResult) async throws -> [LocationResult] {
        let (poi, near) = await splitQueryAndNear(caption)

        var limitParam: Int? = nil
        if let parameters = parameters, let rawParameters = parameters["parameters"] as? NSDictionary {
            if let rawLimit = rawParameters["limit"] as? Int {
                limitParam = rawLimit
            }
        }

        if let near = near, !near.isEmpty {
            // Remote flow: resolve a representative ll for the city, then run remote-biased autocomplete and place search in parallel
            if let coord = try await resolveCoordinateForNear(near) {
                let remoteLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let remoteLR = LocationResult(locationName: near, location: remoteLoc)

                let rawNSDictionary = try await autocomplete(caption: poi, limit: limitParam, locationResult: remoteLR)
                let placesResponseAny = try await placeSearchForAutocomplete(caption: caption, locationResult: remoteLR)

                let rawResponse = (rawNSDictionary as? [String: Any]) ?? [:]
                var results = await parseAutocompleteToLocationResults(rawResponse)

                if let placesDict = placesResponseAny as? [String: Any],
                   let items = placesDict["results"] as? [[String: Any]] {
                    for item in items {
                        guard let geocodes = item["geocodes"] as? [String: Any],
                              let main = geocodes["main"] as? [String: Any],
                              let lat = main["latitude"] as? Double,
                              let lon = main["longitude"] as? Double else { continue }

                        let name = (item["name"] as? String) ?? "Unknown"
                        let locationDict = item["location"] as? [String: Any]
                        let formatted = locationDict?["formatted_address"] as? String

                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                        let lr = LocationResult(locationName: formatted ?? name, location: loc)

                        if !results.contains(where: { existing in
                            existing.locationName == lr.locationName &&
                            abs(existing.location.coordinate.latitude - lr.location.coordinate.latitude) < 1e-6 &&
                            abs(existing.location.coordinate.longitude - lr.location.coordinate.longitude) < 1e-6
                        }) {
                            results.append(lr)
                        }
                    }
                }

                return results
            }
            // If we failed to resolve the city coordinate, fall back to existing local behavior below.
        }

        // Local/default flow
        let rawNSDictionary = try await autocomplete(caption: caption, limit: limitParam, locationResult: locationResult)
        let placesResponseAny = try await placeSearchForAutocomplete(caption: caption, locationResult: locationResult)
        var rawResponse = (rawNSDictionary as? [String: Any]) ?? [:]
        var results = await parseAutocompleteToLocationResults(rawResponse)

        if let placesDict = placesResponseAny as? [String: Any],
           let items = placesDict["results"] as? [[String: Any]] {
            for item in items {
                guard let geocodes = item["geocodes"] as? [String: Any],
                      let main = geocodes["main"] as? [String: Any],
                      let lat = main["latitude"] as? Double,
                      let lon = main["longitude"] as? Double else { continue }

                let name = (item["name"] as? String) ?? "Unknown"
                let locationDict = item["location"] as? [String: Any]
                let formatted = locationDict?["formatted_address"] as? String

                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let lr = LocationResult(locationName: formatted ?? name, location: loc)

                if !results.contains(where: { existing in
                    existing.locationName == lr.locationName &&
                    abs(existing.location.coordinate.latitude - lr.location.coordinate.latitude) < 1e-6 &&
                    abs(existing.location.coordinate.longitude - lr.location.coordinate.longitude) < 1e-6
                }) {
                    results.append(lr)
                }
            }
        }

        return results
    }
    
    private let sessionQueue = DispatchQueue(label: "com.secretatomics.knowmaps.sessionQueue")

    func fetch(url: URL) async throws -> String {
        print("Requesting URL: \(url)")

        // Acquire a configured session before entering the continuation to avoid calling async APIs in non-async closures
        let session = try await self.session()

        return try await withCheckedThrowingContinuation { checkedContinuation in
            var request = URLRequest(url: url)
            request.setValue(self.foursquareApiKey, forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15.0

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    checkedContinuation.resume(throwing: error)
                    return
                }

                guard let d = data else {
                    checkedContinuation.resume(throwing: PlaceSearchSessionError.ServerErrorMessage)
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                    if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message.hasPrefix("Foursquare servers")  {
                        print("Message from server:")
                        print(message)
                        checkedContinuation.resume(throwing: PlaceSearchSessionError.ServerErrorMessage)
                    } else if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message == "Invalid request token." {
                        checkedContinuation.resume(throwing: PlaceSearchSessionError.InvalidSession)
                    } else {
                        checkedContinuation.resume(returning: json as! String)
                    }
                } catch {
                    print(error)
                    let returnedString = String(data: d, encoding: String.Encoding.utf8) ?? ""
                    print(returnedString)
                    checkedContinuation.resume(throwing: PlaceSearchSessionError.ServerErrorMessage)
                }
            }

            task.resume()
        }
    }
    
    public func invalidateSession() async throws {
        try await deleteAPIKeyRecords()
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
            return await ConfiguredSearchSession.shared
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

