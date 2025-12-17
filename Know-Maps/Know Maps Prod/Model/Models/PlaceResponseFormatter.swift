//
//  PlaceResponseFormatter.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation
import ConcurrencyExtras

public enum PlaceResponseFormatterError : Error {
    case InvalidRawResponseType
}

open class PlaceResponseFormatter {
    
    public class func autocompleteTastesResponses(with response:[String:[String]]) throws ->[String] {
        var retval = [String]()

        // v2 endpoints typically nest payload under "response"
        let payload: [String: Any]
        if let nested = response["response"] as? [String: AnyHashableSendable] {
            payload = nested
        } else {
            payload = response
        }

        if let results = payload["tastes"] as? [AnyHashableSendable] {
            for any in results {
                guard let result = any as? [String: AnyHashableSendable] else { continue }
                // id can be String or Int from some v2 responses; coerce to String
                var id: String = ""
                if let rawId = result["id"] as? String {
                    id = rawId
                } else if let rawIdInt = result["id"] as? Int {
                    id = String(rawIdInt)
                }
                let text = (result["text"] as? String) ?? ""
                // Only append if we have at least some identifying text
                if !id.isEmpty || !text.isEmpty {
                    let taste = text
                    retval.append(taste)
                }
            }
        }

        return retval
    }
    
    public class func autocompleteRecommendedPlaceSearchResponses(with response:[String:AnyHashableSendable]) throws ->[RecommendedPlaceSearchResponse] {
        var retval = [RecommendedPlaceSearchResponse]()
        
        guard response.keys.count > 0 else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        if let resultsDict = response["group"] as? NSDictionary {
            if  let results = resultsDict["items"] as? [NSDictionary] {
                for result in results {
                    
                    var fsqID:String = ""
                    var name:String = ""
                    var categories:[String] = [String]()
                    var latitude:Double = 0
                    var longitude:Double = 0
                    var neighborhood:String = ""
                    var address:String = ""
                    var country:String = ""
                    var city:String = ""
                    var state:String = ""
                    var postCode:String = ""
                    var formattedAddress:String = ""
                    var photo:String? = nil
                    var aspectRatio:Float? = nil
                    var photos:[String]  = [String]()
                    let tastes:[String] = [String]()
                    
                    
                    if let venue = result["venue"] as? NSDictionary {
                        if let ident = venue["id"] as? String {
                            fsqID = ident
                        }
                        
                        if let rawName = venue["name"] as? String {
                            name = rawName
                        }
                        
                        if let rawCategoriesArray = venue["categories"] as? [NSDictionary] {
                            for rawCategory in rawCategoriesArray {
                                if let rawName = rawCategory["name"] as? String {
                                    categories.append(rawName)
                                }
                            }
                        }
                        
                        if let rawLocationDict = venue["location"] as? NSDictionary {
                            if let rawAddress = rawLocationDict["address"]  as? String {
                                    address = rawAddress
                            }
                            
                            if let rawCity = rawLocationDict["city"] as? String {
                                    city = rawCity
                            }
                            
                            if let rawPostCode = rawLocationDict["postalCode"] as? String {
                                    postCode = rawPostCode
                            }
                            
                            if let rawState = rawLocationDict["state"]  as? String {
                                    state = rawState
                            }
                            
                            if let rawCountry =  rawLocationDict["country"] as? String {
                                    country = rawCountry
                            }
                            
                            if let rawFormattedAddress = rawLocationDict["formattedAddress"] as? [String] {
                                formattedAddress = rawFormattedAddress.joined(separator: " ")
                            }
                            
                            if let lat = rawLocationDict["lat"] as? Double {
                                latitude = lat
                            }

                            if let lng = rawLocationDict["lng"] as? Double {
                                longitude = lng
                            }
                            
                            if let rawNeighborhood = rawLocationDict["neighborhood"] as? String {
                                neighborhood = rawNeighborhood
                            }
                        }
                    }
                    
                    if let photoDict = result["photo"] as? NSDictionary, let prefix
                        = photoDict["prefix"] as? String, let suffix
                        = photoDict["suffix"] as? String, let width = photoDict["width"] as? Double, let height = photoDict["height"] as? Double{
                        photo = "\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)"
                        aspectRatio = Float(width / height)
                    }
                    
                    if let photosDict = result["photos"] as? NSDictionary,  let groups = photosDict["groups"] as? [NSDictionary] {
                        
                        for group in groups {
                            if let items = group["items"]  as? [NSDictionary] {
                                for item in items {
                                    if let prefix
                                        = item["prefix"] as? String, let suffix
                                        = item["suffix"] as? String, let width = item["width"] as? Double, let height = item["height"] as? Double{
                                        photos.append("\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)")
                                    }
                                }
                            }
                        }
                        
                    }
                    
                    
                    let response = RecommendedPlaceSearchResponse(fsqID: fsqID, name: name, categories: categories, latitude: latitude, longitude: longitude, neighborhood: neighborhood, address:address, country: country, city: city, state: state, postCode: postCode, formattedAddress: formattedAddress, photo: photo, aspectRatio: aspectRatio, photos: photos, tastes: tastes)
                    retval.append(response)
                }
            }
        }
        
        
        return retval
        
    }
    
    public class func recommendedPlaceSearchResponses(with response:[String:Any]) throws ->[RecommendedPlaceSearchResponse] {
        print("🟣 ENTER recommendedPlaceSearchResponses")
        var retval = [RecommendedPlaceSearchResponse]()

        print("🟣 RECOMMENDED FORMATTER INPUT keys: \(response.keys)")
        if let groupAny = response["group"] {
            print("🟣 group type: \(type(of: groupAny))")
        }
        if let resultsAny = response["results"] {
            print("🟣 top-level results type: \(type(of: resultsAny))")
        }
        if let itemsAny = response["items"] {
            print("🟣 top-level items type: \(type(of: itemsAny))")
        }

        // Ensure we got something dictionary-like.
        guard response.keys.count > 0 else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }

        // Helper to coerce heterogeneous array shapes (Any / [[String:Any]] / [NSDictionary])
        func coerceArray(_ any: Any?) -> [NSDictionary]? {
            if let arr = any as? [NSDictionary] {
                return arr
            }
            if let arr = any as? [[String: Any]] {
                return arr.map { $0 as NSDictionary }
            }
            if let arr = any as? [Any] {
                // attempt best-effort cast of each element
                var dicts = [NSDictionary]()
                for el in arr {
                    if let d = el as? [String: Any] {
                        dicts.append(d as NSDictionary)
                    } else if let d = el as? NSDictionary {
                        dicts.append(d)
                    }
                }
                if !dicts.isEmpty {
                    return dicts
                }
            }
            return nil
        }

        // Helper to append one result dictionary (venue wrapper) into retval.
        func appendResult(_ result: NSDictionary) {
            var fsqID:String = ""
            var name:String = ""
            var categories:[String] = [String]()
            var latitude:Double = 0
            var longitude:Double = 0
            var neighborhood:String = ""
            var address:String = ""
            var country:String = ""
            var city:String = ""
            var state:String = ""
            var postCode:String = ""
            var formattedAddress:String = ""
            var photo:String? = nil
            var aspectRatio:Float? = nil
            var photos:[String]  = [String]()
            let tastes:[String] = [String]()

            // Foursquare recs often wrap the venue under "venue".
            let venue = (result["venue"] as? NSDictionary) ?? result

            if let ident = venue["id"] as? String {
                fsqID = ident
            }
            if let rawName = venue["name"] as? String {
                name = rawName
            }
            if let rawCategoriesArray = venue["categories"] as? [NSDictionary] {
                for rawCategory in rawCategoriesArray {
                    if let rawName = rawCategory["name"] as? String {
                        categories.append(rawName)
                    }
                }
            }

            if let rawLocationDict = venue["location"] as? NSDictionary {
                if let rawAddress = rawLocationDict["address"]  as? String {
                    address = rawAddress
                }
                if let rawCity = rawLocationDict["city"] as? String {
                    city = rawCity
                }
                if let rawPostCode = rawLocationDict["postalCode"] as? String {
                    postCode = rawPostCode
                }
                if let rawState = rawLocationDict["state"]  as? String {
                    state = rawState
                }
                if let rawCountry =  rawLocationDict["country"] as? String {
                    country = rawCountry
                }
                if let rawFormattedAddress = rawLocationDict["formattedAddress"] as? [String] {
                    formattedAddress = rawFormattedAddress.joined(separator: " ")
                }
                if let lat = rawLocationDict["lat"] as? Double {
                    latitude = lat
                }
                if let lng = rawLocationDict["lng"] as? Double {
                    longitude = lng
                }
                if let rawNeighborhood = rawLocationDict["neighborhood"] as? String {
                    neighborhood = rawNeighborhood
                }
            }

            // Single hero photo (v2 style)
            if let photoDict = result["photo"] as? NSDictionary,
               let prefix = photoDict["prefix"] as? String,
               let suffix = photoDict["suffix"] as? String,
               let width = photoDict["width"] as? Double,
               let height = photoDict["height"] as? Double {
                photo = "\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)"
                aspectRatio = Float(width/height)
            }

            // Photo groups (alt style)
            if let photosDict = result["photos"] as? NSDictionary,
               let groups = photosDict["groups"] as? [NSDictionary] {
                for group in groups {
                    if let items = group["items"]  as? [NSDictionary] {
                        for item in items {
                            if let prefix = item["prefix"] as? String,
                               let suffix = item["suffix"] as? String,
                               let width = item["width"] as? Double,
                               let height = item["height"] as? Double {
                                photos.append("\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)")
                            }
                        }
                    }
                }
            }

            let rec = RecommendedPlaceSearchResponse(
                fsqID: fsqID,
                name: name,
                categories: categories,
                latitude: latitude,
                longitude: longitude,
                neighborhood: neighborhood,
                address: address,
                country: country,
                city: city,
                state: state,
                postCode: postCode,
                formattedAddress: formattedAddress,
                photo: photo,
                aspectRatio: aspectRatio,
                photos: photos,
                tastes: tastes
            )
            retval.append(rec)
        }

        // Gather all possible candidate arrays in priority order.
        var candidateArrays = [[NSDictionary]]()

        if let groupDict = response["group"] as? NSDictionary {
            let groupResults = coerceArray(groupDict["results"])
            let groupItems   = coerceArray(groupDict["items"])

            if let groupResults, !groupResults.isEmpty {
                print("🟣 using group.results, count=\(groupResults.count)")
                candidateArrays.append(groupResults)
            }
            if let groupItems, !groupItems.isEmpty {
                print("🟣 using group.items, count=\(groupItems.count)")
                candidateArrays.append(groupItems)
            }
        }

        let topResults = coerceArray(response["results"])
        if let topResults, !topResults.isEmpty {
            print("🟣 using top-level results, count=\(topResults.count)")
            candidateArrays.append(topResults)
        }

        let topItems = coerceArray(response["items"])
        if let topItems, !topItems.isEmpty {
            print("🟣 using top-level items, count=\(topItems.count)")
            candidateArrays.append(topItems)
        }

        // Use the first non-empty candidate array.
        if let firstNonEmpty = candidateArrays.first(where: { !$0.isEmpty }) {
            for result in firstNonEmpty {
                appendResult(result)
            }
        }

        return retval
    }

    /// Convert parsed RecommendedPlaceSearchResponse objects (from /v2/search/recommendations)
    /// into PlaceSearchResponse objects that the rest of the UI expects.
    ///
    /// This is needed because performSearch(for:) was previously calling
    /// `placeSearchResponses(with:)` (which expects a raw FSQ "results" dict),
    /// but we actually have `[RecommendedPlaceSearchResponse]` at that point.
    public class func placeSearchResponses(from recommendedPlaceSearchResponses:[RecommendedPlaceSearchResponse]) -> [PlaceSearchResponse] {
        var retVal = [PlaceSearchResponse]()
        
        for response in recommendedPlaceSearchResponses {
            retVal.append(
                PlaceSearchResponse(
                    fsqID: response.fsqID,
                    name: response.name,
                    categories: response.categories,
                    latitude: response.latitude,
                    longitude: response.longitude,
                    address: response.address,
                    addressExtended: response.formattedAddress,
                    country: response.country,
                    dma: response.neighborhood,
                    formattedAddress: response.formattedAddress,
                    locality: response.city,
                    postCode: response.postCode,
                    region: response.state,
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
            )
        }
        
        return retVal
    }
    
    public class func relatedPlaceSearchResponses(with response:[String:AnyHashableSendable]) throws ->[RecommendedPlaceSearchResponse] {
        var retval = [RecommendedPlaceSearchResponse]()
        
        guard response.keys.count > 0 else {
            return retval
        }
        
        if let resultsDictArray = response["related"] as? [NSDictionary] {
            for resultsDict in resultsDictArray {
                
                if  let results = resultsDict["items"] as? [NSDictionary] {
                    for result in results {
                        
                        var fsqID:String = ""
                        var name:String = ""
                        var categories:[String] = [String]()
                        var latitude:Double = 0
                        var longitude:Double = 0
                        var neighborhood:String = ""
                        var address:String = ""
                        var country:String = ""
                        var city:String = ""
                        var state:String = ""
                        var postCode:String = ""
                        var formattedAddress:String = ""
                        var photo:String? = nil
                        var aspectRatio:Float? = nil
                        var photos:[String]  = [String]()
                        let tastes:[String] = [String]()
                        
                        
                        if let venue = result["venue"] as? NSDictionary {
                            if let ident = venue["id"] as? String {
                                fsqID = ident
                            }
                            
                            if let rawName = venue["name"] as? String {
                                name = rawName
                            }
                            
                            if let rawCategoriesArray = venue["categories"] as? [NSDictionary] {
                                for rawCategory in rawCategoriesArray {
                                    if let rawName = rawCategory["name"] as? String {
                                        categories.append(rawName)
                                    }
                                }
                            }
                            
                            if let rawLocationDict = venue["location"] as? NSDictionary {
                                if let rawAddress = rawLocationDict["address"]  as? String {
                                    address = rawAddress
                                }
                                
                                if let rawCity = rawLocationDict["city"] as? String {
                                    city = rawCity
                                }
                                
                                if let rawPostCode = rawLocationDict["postalCode"] as? String {
                                    postCode = rawPostCode
                                }
                                
                                if let rawState = rawLocationDict["state"]  as? String {
                                    state = rawState
                                }
                                
                                if let rawCountry =  rawLocationDict["country"] as? String {
                                    country = rawCountry
                                }
                                
                                if let rawFormattedAddress = rawLocationDict["formattedAddress"] as? [String] {
                                    formattedAddress = rawFormattedAddress.joined(separator: " ")
                                }
                                
                                if let lat = rawLocationDict["lat"] as? Double {
                                    latitude = lat
                                }
                                
                                if let lng = rawLocationDict["lng"] as? Double {
                                    longitude = lng
                                }
                                
                                if let rawNeighborhood = rawLocationDict["neighborhood"] as? String {
                                    neighborhood = rawNeighborhood
                                }
                            }
                        }
                        
                        if let photoDict = result["photo"] as? NSDictionary, let prefix
                            = photoDict["prefix"] as? String, let suffix
                            = photoDict["suffix"] as? String, let width = photoDict["width"] as? Double, let height = photoDict["height"] as? Double{
                            photo = "\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)"
                            aspectRatio = Float(width/height)
                        }
                        
                        if let photosDict = result["photos"] as? NSDictionary,  let groups = photosDict["groups"] as? [NSDictionary] {
                            
                            for group in groups {
                                if let items = group["items"]  as? [NSDictionary] {
                                    for item in items {
                                        if let prefix
                                            = item["prefix"] as? String, let suffix
                                            = item["suffix"] as? String, let width = item["width"] as? Double, let height = item["height"] as? Double{
                                            photos.append("\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)")
                                        }
                                    }
                                }
                            }
                        }
                        
                        let response = RecommendedPlaceSearchResponse(fsqID: fsqID, name: name, categories: categories, latitude: latitude, longitude: longitude, neighborhood: neighborhood, address:address, country: country, city: city, state: state, postCode: postCode, formattedAddress: formattedAddress, photo: photo, aspectRatio: aspectRatio, photos: photos, tastes: tastes)
                        retval.append(response)
                    }
                }
            }

        }
        
        
        return retval
        
    }
    
    
    
    // MARK: - Geo helpers
    /// Build a LocationResult from a Foursquare autocomplete geo item
    /// Expects a container that includes a `geo` dictionary (as returned by autocomplete),
    /// but will also accept the geo dictionary itself.
    public class func locationResult(from resultDict: [String: AnyHashableSendable]) -> LocationResult? {
        print("Autocomplete raw (geo path): \(resultDict)")
        // Accept either a wrapper with `geo` or a direct geo object
        let geoAny = (resultDict["geo"] as? NSDictionary) ?? (resultDict as NSDictionary)
        guard let geo = geoAny as? NSDictionary else { return nil }
        
        let textDict = resultDict["text"] as? NSDictionary
        let primaryName = (textDict?["primary"] as? String) ?? ""
        let geoName = (geo["name"] as? String) ?? ""
        let title = primaryName.isEmpty ? geoName : primaryName
        
        var latitude: Double = 0
        var longitude: Double = 0
        if let center = geo["center"] as? NSDictionary {
            if let lat = (center["lat"] as? NSNumber)?.doubleValue { latitude = lat }
            if let lng = (center["lng"] as? NSNumber)?.doubleValue { longitude = lng }
        }
        
        if title.isEmpty { return nil }
        return LocationResult(locationName: title, location: CLLocation(latitude: latitude, longitude: longitude))
    }
    
    /// Parse an autocomplete array containing only geo-typed entries.
    /// Each entry is expected to be a dictionary with:
    /// - "type": "geo"
    /// - "text": { "primary": String }
    /// - "geo": {
    ///       "cc": String, "type": String, "name": String,
    ///       "center": { "lat": Double, "lng": Double }
    ///   }
    public class func autocompleteGeoEntries(from array: [NSDictionary]) -> [PlaceSearchResponse] {
        print("Autocomplete geo array: \(array)")
        var results: [PlaceSearchResponse] = []
        for item in array {
            guard let type = item["type"] as? String, type == "geo" else { continue }
            let textDict = item["text"] as? NSDictionary
            let primaryName = (textDict?["primary"] as? String) ?? ""
            let geo = item["geo"] as? NSDictionary
            let geoName = (geo?["name"] as? String) ?? ""
            let displayName = primaryName.isEmpty ? geoName : primaryName
            var lat: Double = 0
            var lng: Double = 0
            if let center = geo?["center"] as? NSDictionary {
                if let v = center["lat"] as? NSNumber { lat = v.doubleValue }
                if let v = center["lng"] as? NSNumber { lng = v.doubleValue }
            }
            let countryCode = geo?["cc"] as? String ?? ""
            let regionType = geo?["type"] as? String ?? ""
            // Build a minimal PlaceSearchResponse for a geo entry
            let psr = PlaceSearchResponse(
                fsqID: "", // geo entries don't have fsq_id
                name: displayName,
                categories: [],
                latitude: lat,
                longitude: lng,
                address: "",
                addressExtended: "",
                country: countryCode,
                dma: regionType,
                formattedAddress: geoName,
                locality: "",
                postCode: "",
                region: "",
                chains: [],
                link: "",
                childIDs: [],
                parentIDs: []
            )
            results.append(psr)
        }
        return results
    }
    
    public class func autocompletePlaceSearchResponses(with response:NSDictionary) throws ->[PlaceSearchResponse] {
        var retVal = [PlaceSearchResponse]()
        
        guard response.count > 0 else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        print("Autocomplete raw response: \(response)")
        
        func buildPlaceSearch(from place: NSDictionary, fallbackLink: String? = nil) -> PlaceSearchResponse? {
            var ident = ""
            var name = ""
            var categories = [String]()
            var latitude:Double = 0
            var longitude:Double = 0
            var address = ""
            var addressExtended = ""
            var country = ""
            var dma = ""
            var formattedAddress = ""
            var locality = ""
            var postCode = ""
            var region = ""
            let chains = [String]()
            var link = fallbackLink ?? ""
            var children = [String]()
            let parents = [String]()
            
            if let idString = (place["fsq_id"] as? String) ?? (place["id"] as? String) {
                ident = idString
            }
            if let nameString = place["name"] as? String {
                name = nameString
            }
            if let categoriesArray = place["categories"] as? [NSDictionary] {
                for categoryDict in categoriesArray {
                    if let name = categoryDict["name"] as? String {
                        categories.append(name)
                    }
                }
            }
            // Geocodes
            if let geocodes = place["geocodes"] as? NSDictionary, let mainDict = geocodes["main"] as? NSDictionary {
                if let latitudeNumber = mainDict["latitude"] as? NSNumber {
                    latitude = latitudeNumber.doubleValue
                }
                if let longitudeNumber = mainDict["longitude"] as? NSNumber {
                    longitude = longitudeNumber.doubleValue
                }
            }
            // Location variants
            if let locationDict = place["location"] as? NSDictionary {
                if let addressString = locationDict["address"] as? String { address = addressString }
                if let addressExtendedString = locationDict["address_extended"] as? String { addressExtended = addressExtendedString }
                if let countryString = locationDict["country"] as? String { country = countryString }
                if let dmaString = locationDict["dma"] as? String { dma = dmaString }
                if let formattedAddressString = locationDict["formatted_address"] as? String { formattedAddress = formattedAddressString }
                if let localityString = locationDict["locality"] as? String { locality = localityString }
                if let postCodeString = locationDict["postcode"] as? String { postCode = postCodeString }
                if let regionString = locationDict["region"] as? String { region = regionString }
                if latitude == 0, let lat = locationDict["lat"] as? Double { latitude = lat }
                if longitude == 0, let lng = locationDict["lng"] as? Double { longitude = lng }
            }
            
            if let linkString = place["link"] as? String { link = linkString }
            if let relatedPlacesDict = place["related_places"] as? NSDictionary {
                if let childrenArray = relatedPlacesDict["children"] as? [NSDictionary] {
                    for childDict in childrenArray {
                        if let cid = childDict["fsq_id"] as? String { children.append(cid) }
                    }
                }
            }
            
            if ident.count > 0 || !name.isEmpty { // allow minimal entries for query suggestions
                return PlaceSearchResponse(
                    fsqID: ident,
                    name: name,
                    categories: categories,
                    latitude: latitude,
                    longitude: longitude,
                    address: address,
                    addressExtended: addressExtended,
                    country: country,
                    dma: dma,
                    formattedAddress: formattedAddress,
                    locality: locality,
                    postCode: postCode,
                    region: region,
                    chains: chains,
                    link: link,
                    childIDs: children,
                    parentIDs: parents
                )
            }
            return nil
        }
        
        if let results = response["results"] as? [NSDictionary] {
            for resultDict in results {
                // Primary: place
                if let place = resultDict["place"] as? NSDictionary {
                    if let built = buildPlaceSearch(from: place, fallbackLink: resultDict["link"] as? String) {
                        retVal.append(built)
                    }
                    continue
                }
                // Some variants might return a direct venue
                if let venue = resultDict["venue"] as? NSDictionary {
                    if let built = buildPlaceSearch(from: venue, fallbackLink: resultDict["link"] as? String) {
                        retVal.append(built)
                    }
                    continue
                }
                // Handle minimal query/category suggestions via structured_format
                if let structured = resultDict["structured_format"] as? NSDictionary {
                    var shell: [String: Any] = [:]
                    if let main = structured["main_text"] as? String {
                        shell["name"] = main
                    }
                    if let secondary = structured["secondary_text"] as? String {
                        shell["location"] = ["formatted_address": secondary]
                    }
                    if let built = buildPlaceSearch(from: shell as NSDictionary, fallbackLink: resultDict["link"] as? String) {
                        retVal.append(built)
                    }
                    continue
                }
                // Handle geo result type (e.g., neighborhoods, cities) -> map to a minimal PlaceSearchResponse with coordinates
                if let type = resultDict["type"] as? String, type == "geo", let geo = resultDict["geo"] as? NSDictionary {
                    var shell: [String: Any] = [:]
                    if let text = resultDict["text"] as? NSDictionary, let primary = text["primary"] as? String {
                        shell["name"] = primary
                    } else if let geoName = geo["name"] as? String {
                        shell["name"] = geoName
                    }
                    // Country code and region type can be stored in location formatted address for display
                    var location: [String: Any] = [:]
                    if let geoName = geo["name"] as? String { location["formatted_address"] = geoName }
                    if let center = geo["center"] as? NSDictionary {
                        if let lat = (center["lat"] as? NSNumber)?.doubleValue { location["lat"] = lat }
                        if let lng = (center["lng"] as? NSNumber)?.doubleValue { location["lng"] = lng }
                    }
                    shell["location"] = location
                    if let built = buildPlaceSearch(from: shell as NSDictionary, fallbackLink: resultDict["link"] as? String) {
                        retVal.append(built)
                    }
                    continue
                }
                // Fallback: if the item already looks like a place object
                if let built = buildPlaceSearch(from: resultDict) {
                    retVal.append(built)
                }
            }
        }
        
        return retVal
    }
    
    public class func placeSearchResponses(with response:[String:[NSDictionary]]) throws ->[PlaceSearchResponse] {
        var retVal = [PlaceSearchResponse]()
        
        guard let response = response as? NSDictionary else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        if let results = response["results"] as? [NSDictionary] {
            
            for result in results {
                var ident = ""
                var name = ""
                var categories = [String]()
                var latitude:Double = 0
                var longitude:Double = 0
                var address = ""
                var addressExtended = ""
                var country = ""
                var dma = ""
                var formattedAddress = ""
                var locality = ""
                var postCode = ""
                var region = ""
                let chains = [String]()
                var link = ""
                var children = [String]()
                let parents = [String]()
                
                if let idString = result["fsq_id"] as? String {
                    ident = idString
                }
                
                if let nameString = result["name"] as? String {
                    name = nameString
                }
                if let categoriesArray = result["categories"] as? [NSDictionary] {
                    for categoryDict in categoriesArray {
                        if let name = categoryDict["name"] as? String {
                            categories.append(name)
                        }
                    }
                }
                
                if let geocodes = result["geocodes"] as? NSDictionary {
                    if let mainDict = geocodes["main"] as? NSDictionary {
                        if let latitudeNumber = mainDict["latitude"] as? NSNumber {
                            latitude = latitudeNumber.doubleValue
                        }
                        if let longitudeNumber = mainDict["longitude"] as? NSNumber {
                            longitude = longitudeNumber.doubleValue
                        }
                    }
                }
                
                if let locationDict = result["location"] as? NSDictionary {
                    if let addressString = locationDict["address"] as? String {
                        address = addressString
                    }
                    if let addressExtendedString = locationDict["address_extended"] as? String {
                        addressExtended = addressExtendedString
                    }
                    
                    if let countryString = locationDict["country"] as? String {
                        country = countryString
                    }
                    
                    if let dmaString = locationDict["dma"] as? String {
                        dma = dmaString
                    }
                    
                    if let formattedAddressString = locationDict["formatted_address"] as? String {
                        formattedAddress = formattedAddressString
                    }
                    
                    if let localityString = locationDict["locality"] as? String {
                        locality = localityString
                    }
                    
                    if let postCodeString = locationDict["postcode"] as? String {
                        postCode = postCodeString
                    }
                    
                    if let regionString = locationDict["region"] as? String {
                        region = regionString
                    }
                }
                
                /*
                 if let chainsArray = response["chain"] as? [NSDictionary] {
                 for chainDict in chainsArray {
                 
                 }
                 }
                 */
                
                if let linkString = response["link"] as? String {
                    link = linkString
                }
                
                if let relatedPlacesDict = response["related_places"] as? NSDictionary {
                    if let childrenArray = relatedPlacesDict["children"] as? [NSDictionary] {
                        for childDict in childrenArray {
                            if let ident = childDict["fsq_id"] as? String {
                                children.append(ident)
                            }
                        }
                    }
                }
                
                if ident.count > 0 {
                    let response = PlaceSearchResponse(fsqID: ident, name: name, categories: categories, latitude: latitude, longitude: longitude, address: address, addressExtended: addressExtended, country: country, dma: dma, formattedAddress: formattedAddress, locality: locality, postCode: postCode, region: region, chains: chains, link: link, childIDs: children, parentIDs: parents)
                    retVal.append(response)
                }
            }
        }
        
        return retVal
    }
    
    public class func placeDetailsResponse(with response:Any, for placeSearchResponse:PlaceSearchResponse, placePhotosResponses:[PlacePhotoResponse]? = nil, placeTipsResponses:[PlaceTipsResponse]? = nil, previousDetails:[PlaceDetailsResponse]? = nil) async throws ->PlaceDetailsResponse {
        
        guard let response = response as? NSDictionary else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        var searchResponse = placeSearchResponse
        
        if searchResponse.name.isEmpty {
            let embeddedSearchResponseDict = ["results":[response]]
            let embeddedSearchResponse = try placeSearchResponses(with: embeddedSearchResponseDict).first
            if let embeddedSearchResponse = embeddedSearchResponse {
                searchResponse = embeddedSearchResponse
            }
        }
        
        var description:String?
        
        if let rawDescription = response["description"] as? String {
            print(rawDescription)
            description = rawDescription
        } else if let previousDetails = previousDetails {
            for detail in previousDetails {
                if detail.searchResponse.fsqID == searchResponse.fsqID, let desc = detail.description, !desc.isEmpty  {
                    description = detail.description
                }
            }
        }
        
        var tel:String? = nil
        if let rawTel = response["tel"] as? String {
            tel = rawTel
        }
        
        var fax:String? = nil
        if let rawFax = response["fax"] as? String {
            fax = rawFax
        }
        
        var email:String? = nil
        if let rawEmail = response["email"] as? String {
            email = rawEmail
        }
        
        var website:String? = nil
        if let rawWebsite = response["website"] as? String {
            website = rawWebsite
        }
        
        var socialMedia:[String:String]? = nil
        if let rawSocialMedia = response["social_media"] as? [String:String] {
            socialMedia = rawSocialMedia
        }
        
        var verified:Bool? = nil
        verified = false
        
        var hours:String? = nil
        var openNow:Bool? = nil
        if let hoursDict = response["hours"] as? NSDictionary {
            if let hoursDisplayText = hoursDict["display"] as? String {
                hours = hoursDisplayText
            }
            if let rawOpen = hoursDict["open_now"] as? Int {
                if rawOpen == 1 {
                    openNow = true
                } else {
                    openNow = false
                }
            }
        }
        
        var hoursPopular:[[String:Int]]? = nil
        if let rawHoursPopular = response["hours_popular"] as? [[String:Int]] {
            hoursPopular = rawHoursPopular
        }
        var rating:Float = 0
        if let rawRating = response["rating"] as? Double {
            rating = Float(rawRating)
        }
        var stats:Bool? = nil
        stats = false
        var popularity:Float = 0
        if let rawPopularity = response["popularity"] as? Double {
            popularity = Float(rawPopularity)
        }
        var price:Int? = nil
        if let rawPrice = response["price"] as? Int {
            price = rawPrice
        }
        
        var dateClosed:String? = nil
        if let rawDateClosed = response["date_closed"] as? String {
            dateClosed = rawDateClosed
        }
        
        var tastes:[String]? = nil
        if let rawTastes = response["tastes"] as? [String] {
            tastes = rawTastes
        }
        
        let features:[String]? = nil
        
        var photoResponses = placePhotosResponses
        if photoResponses == nil, let responses = response["photos"] as? [NSDictionary] {
            photoResponses = try PlaceResponseFormatter.placePhotoResponses(with: responses, for: searchResponse.fsqID)
        }
        
        var tipsResponses = placeTipsResponses
        if tipsResponses == nil, let responses = response["tips"] as? [NSDictionary] {
            tipsResponses = try PlaceResponseFormatter.placeTipsResponses(with: responses, for: searchResponse.fsqID)
        }
        
        return PlaceDetailsResponse(searchResponse: searchResponse, photoResponses: photoResponses, tipsResponses: tipsResponses, description: description, tel: tel, fax: fax, email: email, website: website, socialMedia: socialMedia, verified: verified, hours: hours, openNow: openNow, hoursPopular: hoursPopular, rating: rating, stats: stats, popularity: popularity, price: price, dateClosed: dateClosed, tastes: tastes, features: features)
        
    }
    
    public class func placePhotoResponses(with response:Any, for placeID:String) throws ->[PlacePhotoResponse] {
        var retVal = [PlacePhotoResponse]()
        
        if let response = response as? NSDictionary, response.allKeys.count == 0 {
            return retVal
        }
        
        guard let response = response as? [NSDictionary] else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        for photoDict in response {
            var ident = ""
            var createdAt = ""
            var height:Float = 1.0
            var width:Float = 0.0
            var classifications = [String]()
            var prefix = ""
            var suffix = ""
            if let idString = photoDict["id"] as? String {
                ident = idString
            }
            if let createdAtString = photoDict["created_at"] as? String {
                createdAt = createdAtString
            }
            if let heightNumber = photoDict["height"] as? NSNumber {
                height = heightNumber.floatValue
            }
            if let widthNumber = photoDict["width"] as? NSNumber {
                width = widthNumber.floatValue
            }
            if let classificationsArray = photoDict["classifications"] as? [String] {
                classifications = classificationsArray
            }
            if let prefixString = photoDict["prefix"] as? String {
                prefix = prefixString
            }
            if let suffixString = photoDict["suffix"] as? String {
                suffix = suffixString
            }
            
            let response = PlacePhotoResponse(id: ObjectIdentifier(NSString(string:ident)), placeIdent:placeID, ident: ident, createdAt: createdAt, height: height, width: width, classifications: classifications, prefix: prefix, suffix: suffix)
            retVal.append(response)
        }
        return retVal
    }
    
    public class func placeTipsResponses( with response:Any, for placeID:String) throws ->[PlaceTipsResponse] {
        var retVal = [PlaceTipsResponse]()
        var containsID = Set<String>()
        if let response = response as? NSDictionary, response.allKeys.count == 0 {
            return retVal
        }
        
        guard let response = response as? [NSDictionary] else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        for tipDict in response {
            var ident = ""
            var createdAt = ""
            var text = ""
            
            if let idString = tipDict["id"] as? String {
                ident = idString
            }
            
            if let createdAtString = tipDict["created_at"] as? String {
                createdAt = createdAtString
            }
            
            if let textString = tipDict["text"] as? String {
                text = textString
            }
            
            let response = PlaceTipsResponse(id:ident, placeIdent:placeID, ident: ident, createdAt: createdAt, text: text)
            if !containsID.contains(response.id){
                containsID.insert(response.id)
                retVal.append(response)
            }
        }
        return retVal
    }
        
    public class func placeChatResults(for intent:AssistiveChatHostIntent, place:PlaceSearchResponse, section:PersonalizedSearchSection, list:String, index:Int, rating:Double, details:PlaceDetailsResponse?, recommendedPlaceResponse:RecommendedPlaceSearchResponse? = nil)->[ChatResult] {
        return [PlaceResponseFormatter.chatResult(index: index, title: place.name, section:section, list:list, rating:rating, placeResponse: place, placeDetailsResponse: details, recommendedPlaceResponse: recommendedPlaceResponse)]
    }
    
    public class func chatResult(index:Int, title:String, section:PersonalizedSearchSection, list:String, rating:Double, placeResponse:PlaceSearchResponse, placeDetailsResponse:PlaceDetailsResponse?, recommendedPlaceResponse:RecommendedPlaceSearchResponse? = nil)->ChatResult {
        let result = ChatResult(index: index, identity: placeResponse.fsqID, title:title, list:list, icon: "", rating: rating, section:section, placeResponse: placeResponse, recommendedPlaceResponse: recommendedPlaceResponse, placeDetailsResponse:placeDetailsResponse)
                        
        return result
    }
}

