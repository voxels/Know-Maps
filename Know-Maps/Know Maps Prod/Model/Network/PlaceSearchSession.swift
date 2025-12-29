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

@inline(__always)
private func stringify<T>(_ value: T?) -> String {
    if let v = value { return String(describing: v) }
    return "nil"
}

protocol JSONRepresentable { func toJSON() -> [String: Any] }

extension Array where Element: JSONRepresentable {
    func toJSON() -> [[String: Any]] { self.map { $0.toJSON() } }
}

public struct FSQCategory: Codable, Sendable, Hashable, Equatable {
    let id: Int?
    let name: String?
}
extension FSQCategory: CustomStringConvertible {
    public var description: String { "FSQCategory(id: \(stringify(id)), name: \(name ?? "nil"))" }
    public var stringValue: String { description }
}
extension FSQCategory: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let id = id { dict["id"] = id }
        if let name = name { dict["name"] = name }
        return dict
    }
}

public struct FSQGeocodePoint: Codable, Sendable {
    let latitude: Double?
    let longitude: Double?
}
extension FSQGeocodePoint: CustomStringConvertible {
    public var description: String { "FSQGeocodePoint(latitude: \(stringify(latitude)), longitude: \(stringify(longitude)))" }
    public var stringValue: String { description }
}
extension FSQGeocodePoint: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let latitude = latitude { dict["latitude"] = latitude }
        if let longitude = longitude { dict["longitude"] = longitude }
        return dict
    }
}

public struct FSQGeocodes: Codable, Sendable {
    let main: FSQGeocodePoint?
    let roof: FSQGeocodePoint?
}
extension FSQGeocodes: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let main = main { dict["main"] = main.toJSON() }
        if let roof = roof { dict["roof"] = roof.toJSON() }
        return dict
    }
}

public struct FSQLocation: Codable, Sendable {
    let address: String?
    let address_extended: String?
    let locality: String?
    let region: String?
    let postcode: String?
    let country: String?
    let neighborhood: FSQStringArray?
    let formatted_address: String?
}
extension FSQLocation: CustomStringConvertible {
    public var description: String { "FSQLocation(formatted_address: \(formatted_address ?? "nil"))" }
    public var stringValue: String { description }
}
extension FSQLocation: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let address = address { dict["address"] = address }
        if let address_extended = address_extended { dict["address_extended"] = address_extended }
        if let locality = locality { dict["locality"] = locality }
        if let region = region { dict["region"] = region }
        if let postcode = postcode { dict["postcode"] = postcode }
        if let country = country { dict["country"] = country }
        if let neighborhood = neighborhood { dict["neighborhood"] = neighborhood.values }
        if let formatted_address = formatted_address { dict["formatted_address"] = formatted_address }
        return dict
    }
}

public struct FSQStringArray: Codable, Sendable {
    let values: [String]

    init(_ values: [String]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self.values = array
        } else if let string = try? container.decode(String.self) {
            self.values = [string]
        } else {
            self.values = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

public struct FSQStringOrInt: Codable, Sendable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = String(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = String(boolValue)
        } else {
            self.value = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public struct FSQSocialMedia: Codable, Sendable {
    let facebook_id: FSQStringOrInt?
    let instagram: String?
    let twitter: String?

    var dictionaryValue: [String: String] {
        var dict: [String: String] = [:]
        if let facebook_id, !facebook_id.value.isEmpty { dict["facebook_id"] = facebook_id.value }
        if let instagram, !instagram.isEmpty { dict["instagram"] = instagram }
        if let twitter, !twitter.isEmpty { dict["twitter"] = twitter }
        return dict
    }
}

public struct FSQHours: Codable, Sendable {
    let display: String?
    let open_now: Bool?
}

public struct FSQPlace: Codable, Sendable {
    let fsq_id: String?
    let name: String?
    let geocodes: FSQGeocodes?
    let location: FSQLocation?
    let categories: [FSQCategory]?

    let place_description: String?
    let tel: String?
    let fax: String?
    let email: String?
    let website: String?
    let social_media: FSQSocialMedia?
    let verified: Bool?
    let hours: FSQHours?
    let rating: Double?
    let popularity: Double?
    let price: Int?
    let date_closed: String?
    let tastes: [String]?

    private enum CodingKeys: String, CodingKey {
        case fsq_id
        case name
        case geocodes
        case location
        case categories
        case place_description = "description"
        case tel
        case fax
        case email
        case website
        case social_media
        case verified
        case hours
        case rating
        case popularity
        case price
        case date_closed
        case tastes
    }
}
extension FSQPlace: CustomStringConvertible {
    public var description: String {
        let idStr = fsq_id ?? "nil"
        let nameStr = name ?? "nil"
        return "FSQPlace(fsq_id: \(idStr), name: \(nameStr))"
    }
    public var stringValue: String { description }
}

extension FSQPlace: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let fsq_id = fsq_id { dict["fsq_id"] = fsq_id }
        if let name = name { dict["name"] = name }
        if let geocodes = geocodes { dict["geocodes"] = geocodes.toJSON() }
        if let location = location { dict["location"] = location.toJSON() }
        if let categories = categories { dict["categories"] = categories.toJSON() }
        return dict
    }
}

public struct FSQSearchResponse: Codable, Sendable {
    let results: [FSQPlace]?
}
extension FSQSearchResponse: CustomStringConvertible {
    public var description: String { "FSQSearchResponse(results_count: \(results?.count ?? 0))" }
    public var stringValue: String { description }
}
extension FSQSearchResponse: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let results = results { dict["results"] = results.toJSON() }
        return dict
    }
}

// Autocomplete models
public struct FSQAutocompletePlaceWrapper: Codable, Sendable {
    let name: String?
    let geocodes: FSQGeocodes?
    let location: FSQLocation?
}
extension FSQAutocompletePlaceWrapper: CustomStringConvertible {
    public var description: String {
        let nameStr = name ?? "nil"
        return "FSQAutocompletePlaceWrapper(name: \(nameStr))"
    }
    public var stringValue: String { description }
}
extension FSQAutocompletePlaceWrapper: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let name = name { dict["name"] = name }
        if let geocodes = geocodes { dict["geocodes"] = geocodes.toJSON() }
        if let location = location { dict["location"] = location.toJSON() }
        return dict
    }
}

public struct FSQAutocompleteItem: Codable, Sendable {
    let type: String
    let text: String?
    let name: String?
    let formatted_address: String?
    let center: FSQGeocodePoint?
    let geocodes: FSQGeocodes?
    let place: FSQAutocompletePlaceWrapper?
    
    // return a json dictionary representation
    public func toJSON() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let text = text { dict["text"] = text }
        if let name = name { dict["name"] = name }
        if let formatted_address = formatted_address { dict["formatted_address"] = formatted_address }
        if let center = center { dict["center"] = center.toJSON() }
        if let geocodes = geocodes { dict["geocodes"] = geocodes.toJSON() }
        if let place = place { dict["place"] = place.toJSON() }
        return dict
    }
}
extension FSQAutocompleteItem: CustomStringConvertible {
    public var description: String {
        let typeStr = type
        let textStr = text ?? "nil"
        let nameStr = name ?? "nil"
        let formattedStr = formatted_address ?? "nil"
        return "FSQAutocompleteItem(type: \(typeStr), text: \(textStr), name: \(nameStr), formatted_address: \(formattedStr))"
    }
    public var stringValue: String { description }
}
extension FSQAutocompleteItem: JSONRepresentable {}

public struct FSQAutocompleteResponse: Codable, Sendable {
    let results: [FSQAutocompleteItem]?
}
extension FSQAutocompleteResponse: CustomStringConvertible {
    public var description: String { "FSQAutocompleteResponse(results_count: \(results?.count ?? 0))" }
    public var stringValue: String { description }
}
extension FSQAutocompleteResponse: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let results = results { dict["results"] = results.toJSON() }
        return dict
    }
}

public struct FSQPhoto: Codable, Sendable {
    let id: String?
    let created_at: String?
    let prefix: String?
    let suffix: String?
    let width: Int?
    let height: Int?
}
extension FSQPhoto: CustomStringConvertible {
    public var description: String {
        let idStr = id ?? "nil"
        let createdStr = created_at ?? "nil"
        let prefixStr = prefix ?? "nil"
        let suffixStr = suffix ?? "nil"
        let widthStr = stringify(width)
        let heightStr = stringify(height)
        return "FSQPhoto(id: \(idStr), created_at: \(createdStr), prefix: \(prefixStr), suffix: \(suffixStr), width: \(widthStr), height: \(heightStr))"
    }
    public var stringValue: String { description }
}
extension FSQPhoto: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let id = id { dict["id"] = id }
        if let created_at = created_at { dict["created_at"] = created_at }
        if let prefix = prefix { dict["prefix"] = prefix }
        if let suffix = suffix { dict["suffix"] = suffix }
        if let width = width { dict["width"] = width }
        if let height = height { dict["height"] = height }
        return dict
    }
}
public typealias FSQPhotosResponse = [FSQPhoto]

public struct FSQTip: Codable, Sendable {
    let id: String?
    let text: String?
    let created_at: String?
}
extension FSQTip: CustomStringConvertible {
    public var description: String {
        let idStr = id ?? "nil"
        let textStr = text ?? "nil"
        let createdStr = created_at ?? "nil"
        return "FSQTip(id: \(idStr), text: \(textStr), created_at: \(createdStr))"
    }
    public var stringValue: String { description }
}
extension FSQTip: JSONRepresentable {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let id = id { dict["id"] = id }
        if let text = text { dict["text"] = text }
        if let created_at = created_at { dict["created_at"] = created_at }
        return dict
    }
}
public struct FSQTaste: Codable, Sendable {
    public let id: String?
    public let text: String?
}

public struct FSQTastesResponse: Codable, Sendable {
    public let tastes: [FSQTaste]?
}

public struct FSQTastesRoot: Codable, Sendable {
    public let response: FSQTastesResponse?
}

public enum PlaceSearchSessionError : Error {
    case ServiceNotFound
    case UnsupportedRequest
    case ServerErrorMessage
    case NoPlaceLocationsFound
    case InvalidSession
}

public actor PlaceSearchSession : PlaceSearchSessionProtocol, ObservableObject {
    public var proactiveCacheService: ProactiveCacheService?
    static let foursquareVersionDate = "20241227"
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
    public func query(request:PlaceSearchRequest) async throws -> FSQSearchResponse {
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
        
        // Add version parameter for consistent latest behavior
        queryItems.append(URLQueryItem(name: "v", value: PlaceSearchSession.foursquareVersionDate))
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let response: FSQSearchResponse = try await fetch(url: url, as: FSQSearchResponse.self)
        
        return response
    }
    
    public func details(for request:PlaceDetailsRequest) async throws -> FSQPlace {
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
        let versionQueryItem = URLQueryItem(name: "v", value: PlaceSearchSession.foursquareVersionDate)
        components?.queryItems = [queryItem, versionQueryItem]
        
        guard let url = components?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        
        let response: FSQPlace = try await fetch(url: url, as: FSQPlace.self)
        return response
    }
    
    public func photos(for fsqID:String) async throws -> FSQPhotosResponse {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placePhotosAPIUrl)")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(50)")
        let sortQueryItem = URLQueryItem(name:"sort", value:"newest")
        let versionQueryItem = URLQueryItem(name: "v", value: PlaceSearchSession.foursquareVersionDate)
        queryComponents?.queryItems = [limitQueryItem, sortQueryItem, versionQueryItem]
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let response: FSQPhotosResponse = try await fetch(url: url, as: FSQPhotosResponse.self)
        return response
    }
    
    public func tips(for fsqID:String) async throws -> [FSQTip] {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.placeDetailsAPIUrl)\(fsqID)\(PlaceSearchSession.placeTipsAPIUrl)")
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(50)")
        let versionQueryItem = URLQueryItem(name: "v", value: PlaceSearchSession.foursquareVersionDate)
        let queryItems = [limitQueryItem, versionQueryItem]
        queryComponents?.queryItems = queryItems
        
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let response: [FSQTip] = try await fetch(url: url, as: [FSQTip].self)
        return response
    }
    
    public func autocomplete(caption: String, limit: Int?, locationResult: LocationResult) async throws -> FSQAutocompleteResponse {
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
        
        let versionQueryItem = URLQueryItem(name: "v", value: PlaceSearchSession.foursquareVersionDate)
        queryItems.append(versionQueryItem)
        
        queryComponents?.queryItems = queryItems
        
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let response: FSQAutocompleteResponse = try await fetch(url: url, as: FSQAutocompleteResponse.self)
        return response
    }
    
    public func searchLocations(caption: String, locationResult: LocationResult?) async throws -> [LocationResult] {
        var queryComponents = URLComponents(string:"\(PlaceSearchSession.serverUrl)\(PlaceSearchSession.autocompleteAPIUrl)")
        var queryItems = [URLQueryItem]()
        
        let queryUrlItem = URLQueryItem(name: "query", value: caption)
        queryItems.append(queryUrlItem)
        
        let typesItem = URLQueryItem(name: "types", value: "geo,address,place")
        queryItems.append(typesItem)
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "20")
        queryItems.append(limitQueryItem)
        
        let versionQueryItem = URLQueryItem(name: "v", value: PlaceSearchSession.foursquareVersionDate)
        queryItems.append(versionQueryItem)
        
        if let loc = locationResult?.location {
            let ll = "\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
            queryItems.append(URLQueryItem(name: "ll", value: ll))
            queryItems.append(URLQueryItem(name: "radius", value: "100000"))
        }
        
        queryComponents?.queryItems = queryItems
        
        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let response: FSQAutocompleteResponse = try await fetch(url: url, as: FSQAutocompleteResponse.self)
        return parseAutocompleteToLocationResults(response)
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
    
    private func placeSearchForAutocomplete(caption: String, locationResult: LocationResult) async throws -> FSQSearchResponse {
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
    
    private func parseAutocompleteToLocationResults(_ response: FSQAutocompleteResponse) -> [LocationResult] {
        var results: [LocationResult] = []
        
        for item in response.results ?? [] {
            switch item.type {
            case "place":
                guard let place = item.place else { continue }
                let name = place.name ?? "Unknown"
                let formatted = place.location?.formatted_address
                
                var lat: Double?
                var lon: Double?
                if let main = place.geocodes?.main {
                    lat = main.latitude
                    lon = main.longitude
                }
                if (lat == nil || lon == nil), let roof = place.geocodes?.roof {
                    lat = roof.latitude
                    lon = roof.longitude
                }
                
                if let lat = lat, let lon = lon {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let lr = LocationResult(locationName: name, location: loc, formattedAddress: formatted)
                    results.append(lr)
                }
                
            case "address":
                let text = item.text ?? item.name ?? "Address"
                let formatted = item.formatted_address
                
                var lat: Double?
                var lon: Double?
                if let main = item.geocodes?.main {
                    lat = main.latitude
                    lon = main.longitude
                }
                if (lat == nil || lon == nil), let center = item.center {
                    lat = center.latitude
                    lon = center.longitude
                }
                
                if let lat = lat, let lon = lon {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let lr = LocationResult(locationName: text, location: loc, formattedAddress: formatted)
                    results.append(lr)
                }
                
            case "geo":
                let text = item.text ?? item.name ?? "Area"
                
                var lat: Double?
                var lon: Double?
                if let center = item.center {
                    lat = center.latitude
                    lon = center.longitude
                }
                if (lat == nil || lon == nil), let main = item.geocodes?.main {
                    lat = main.latitude
                    lon = main.longitude
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
        let resp = try? await self.query(request: request)
        guard let mainPoint = resp?.results?.first?.geocodes?.main,
              let lat = mainPoint.latitude,
              let lon = mainPoint.longitude else {
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
                
                let auto: FSQAutocompleteResponse = try await autocomplete(caption: poi, limit: limitParam, locationResult: remoteLR)
                let placesResponse = try await placeSearchForAutocomplete(caption: caption, locationResult: remoteLR)
                
                var results = await parseAutocompleteToLocationResults(auto)
                
                for item in placesResponse.results ?? [] {
                    guard let lat = item.geocodes?.main?.latitude,
                          let lon = item.geocodes?.main?.longitude else { continue }
                    
                    let name = item.name ?? "Unknown"
                    let formatted = item.location?.formatted_address
                    
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
                
                return results
            }
            // If we failed to resolve the city coordinate, fall back to existing local behavior below.
        }
        
        // Local/default flow
        let auto: FSQAutocompleteResponse = try await autocomplete(caption: caption, limit: limitParam, locationResult: locationResult)
        let placesResponse = try await placeSearchForAutocomplete(caption: caption, locationResult: locationResult)
        var results = await parseAutocompleteToLocationResults(auto)
        
        for item in placesResponse.results ?? [] {
            guard let lat = item.geocodes?.main?.latitude,
                  let lon = item.geocodes?.main?.longitude else { continue }
            
            let name = item.name ?? "Unknown"
            let formatted = item.location?.formatted_address
            
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
        
        return results
    }
    
    private let sessionQueue = DispatchQueue(label: "com.secretatomics.knowmaps.sessionQueue")
    
    func fetch<T: Decodable & Sendable>(url: URL, as type: T.Type) async throws -> T {
        print("Requesting URL: \(url)")
        
        // Check proactive cache first
        if let proactiveCache = await proactiveCacheService {
            // Use URL absolute string as the cache identity for fine-grained network caching
            if let cachedData = await proactiveCache.retrieve(identity: url.absoluteString),
               let decoded = try? JSONDecoder().decode(T.self, from: cachedData) {
#if DEBUG
                print("[ProactiveCache] Hit for \(url.absoluteString)")
#endif
                return decoded
            }
        }
        
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
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode(T.self, from: d)
                    
                    // Store in proactive cache for future hits
                    let dataToCache = d
                    let cacheIdentity = url.absoluteString
                    Task { [weak self] in
                        if let self = self, let proactiveCache = await self.proactiveCacheService {
                            await proactiveCache.store(identity: cacheIdentity, data: dataToCache)
                        }
                    }
                    
                    checkedContinuation.resume(returning: decoded)
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
        
        // Thread-safe container for the found key
        class KeyBox: @unchecked Sendable {
            var value: String?
            let lock = NSLock()
            func set(_ val: String) {
                lock.lock()
                value = val
                lock.unlock()
            }
            func get() -> String? {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
        }
        let keyBox = KeyBox()
        
        operation.recordMatchedBlock = { recordId, result in
            do {
                let record = try result.get()
                if let apiKey = record["value"] as? String {
                    if let serviceName = record["service"] as? String {
                        print("Found API Key for service: \(serviceName)")
                    }
                    keyBox.set(apiKey)
                }
            } catch {
                print("Error matching record: \(error)")
            }
        }
        
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated
        
        let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            operation.queryResultBlock = { [weak self] result in
                let foundKey = keyBox.get()
                
                Task { [weak self] in
                    guard let self = self else { return }
                    if let key = foundKey {
                        await self.setFoursquareApiKey(key)
                    } else {
                        print("Did not find API Key for \(service)")
                    }
                    await self.resumeContinuation(continuation, with: result)
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
    
    nonisolated func setFoursquareApiKey(_ key: String) async {
        await self.foursquareApiKeySet(key)
    }

    nonisolated func resumeContinuation(_ continuation: CheckedContinuation<Bool, Error>, with result: Result<CKQueryOperation.Cursor?, Error>) async {
        await self.handleQueryResult(continuation: continuation, result: result)
    }

    private func foursquareApiKeySet(_ key: String) {
        self.foursquareApiKey = key
    }

    private func handleQueryResult(continuation: CheckedContinuation<Bool, Error>, result: Result<CKQueryOperation.Cursor?, Error>) {
        switch result {
        case .success:
            continuation.resume(returning: true)
        case .failure(let error):
            print("Query error: \(error)")
            continuation.resume(returning: false)
        }
    }
}
