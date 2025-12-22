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
    
    // MARK: - Legacy v2 Codable helpers
    private struct V2GroupContainer: Codable { let items: [V2GroupItem]? }
    private struct V2VenueCategory: Codable { let name: String? }
    private struct V2VenueLocation: Codable {
        let address: String?
        let city: String?
        let postalCode: String?
        let state: String?
        let country: String?
        let formattedAddress: [String]?
        let lat: Double?
        let lng: Double?
        let neighborhood: String?
    }
    private struct V2Venue: Codable {
        let id: String?
        let name: String?
        let categories: [V2VenueCategory]?
        let location: V2VenueLocation?
    }
    private struct V2Photo: Codable { let prefix: String?; let suffix: String?; let width: Double?; let height: Double? }
    private struct V2PhotoGroup: Codable { let items: [V2Photo]? }
    private struct V2PhotosContainer: Codable { let groups: [V2PhotoGroup]? }
    private struct V2GroupItem: Codable {
        let venue: V2Venue?
        let photo: V2Photo?
        let photos: V2PhotosContainer?
    }
    private struct V2RecommendedRoot: Codable { let group: V2GroupContainer? }
    private struct V2RelatedGroup: Codable { let items: [V2GroupItem]? }
    private struct V2RelatedRoot: Codable { let related: [V2RelatedGroup]? }

    public class func autocompleteTastesResponses(with response:[String:[String]]) throws ->[String] {
        var retval = [String]()
        // Support both nested and flat payloads as loosely typed arrays of dictionaries
        if let nested = response["response"] as? [[String: Any]],
           let tastes = nested.first?["tastes"] as? [[String: Any]] {
            for t in tastes {
                if let text = t["text"] as? String, !text.isEmpty { retval.append(text) }
            }
            return retval
        }
        if let tastes = response["tastes"] as? [[String: Any]] {
            for t in tastes {
                if let text = t["text"] as? String, !text.isEmpty { retval.append(text) }
            }
        }
        return retval
    }
    
    public class func autocompleteRecommendedPlaceSearchResponses(from data: Data) throws -> [RecommendedPlaceSearchResponse] {
        var results: [RecommendedPlaceSearchResponse] = []
        let decoder = JSONDecoder()
        let root = try decoder.decode(V2RecommendedRoot.self, from: data)
        guard let items = root.group?.items, !items.isEmpty else { return results }
        for item in items {
            var fsqID = ""
            var name = ""
            var categories: [String] = []
            var latitude: Double = 0
            var longitude: Double = 0
            var neighborhood = ""
            var address = ""
            var country = ""
            var city = ""
            var state = ""
            var postCode = ""
            var formattedAddress = ""
            var photo: String? = nil
            var aspectRatio: Float? = nil
            var photos: [String] = []
            let tastes: [String] = []

            if let v = item.venue {
                fsqID = v.id ?? ""
                name = v.name ?? ""
                categories = (v.categories ?? []).compactMap { $0.name }
                if let loc = v.location {
                    address = loc.address ?? ""
                    city = loc.city ?? ""
                    postCode = loc.postalCode ?? ""
                    state = loc.state ?? ""
                    country = loc.country ?? ""
                    if let fa = loc.formattedAddress { formattedAddress = fa.joined(separator: " ") }
                    if let lat = loc.lat { latitude = lat }
                    if let lng = loc.lng { longitude = lng }
                    neighborhood = loc.neighborhood ?? ""
                }
            }
            if let p = item.photo, let prefix = p.prefix, let suffix = p.suffix, let w = p.width, let h = p.height {
                photo = "\(prefix)\(Int(floor(w)))x\(Int(floor(h)))\(suffix)"
                aspectRatio = Float(w/h)
            }
            if let groups = item.photos?.groups {
                for g in groups {
                    for i in g.items ?? [] {
                        if let prefix = i.prefix, let suffix = i.suffix, let w = i.width, let h = i.height {
                            photos.append("\(prefix)\(Int(floor(w)))x\(Int(floor(h)))\(suffix)")
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
            results.append(rec)
        }
        return results
    }
    
    public class func relatedPlaceSearchResponses(from data: Data) throws -> [RecommendedPlaceSearchResponse] {
        var results: [RecommendedPlaceSearchResponse] = []
        let decoder = JSONDecoder()
        let root = try decoder.decode(V2RelatedRoot.self, from: data)
        for group in root.related ?? [] {
            for item in group.items ?? [] {
                var fsqID = ""
                var name = ""
                var categories: [String] = []
                var latitude: Double = 0
                var longitude: Double = 0
                var neighborhood = ""
                var address = ""
                var country = ""
                var city = ""
                var state = ""
                var postCode = ""
                var formattedAddress = ""
                var photo: String? = nil
                var aspectRatio: Float? = nil
                var photos: [String] = []
                let tastes: [String] = []

                if let v = item.venue {
                    fsqID = v.id ?? ""
                    name = v.name ?? ""
                    categories = (v.categories ?? []).compactMap { $0.name }
                    if let loc = v.location {
                        address = loc.address ?? ""
                        city = loc.city ?? ""
                        postCode = loc.postalCode ?? ""
                        state = loc.state ?? ""
                        country = loc.country ?? ""
                        if let fa = loc.formattedAddress { formattedAddress = fa.joined(separator: " ") }
                        if let lat = loc.lat { latitude = lat }
                        if let lng = loc.lng { longitude = lng }
                        neighborhood = loc.neighborhood ?? ""
                    }
                }
                if let p = item.photo, let prefix = p.prefix, let suffix = p.suffix, let w = p.width, let h = p.height {
                    photo = "\(prefix)\(Int(floor(w)))x\(Int(floor(h)))\(suffix)"
                    aspectRatio = Float(w/h)
                }
                if let groups = item.photos?.groups {
                    for g in groups {
                        for i in g.items ?? [] {
                            if let prefix = i.prefix, let suffix = i.suffix, let w = i.width, let h = i.height {
                                photos.append("\(prefix)\(Int(floor(w)))x\(Int(floor(h)))\(suffix)")
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
                results.append(rec)
            }
        }
        return results
    }
    
    // MARK: - Geo helpers
    /// Build a LocationResult from a Foursquare autocomplete geo item
    /// Expects a FSQAutocompleteItem with type "geo"
    public class func locationResult(from item: FSQAutocompleteItem) -> LocationResult? {
        guard item.type == "geo" else { return nil }
        let title = item.text ?? item.name ?? ""
        guard !title.isEmpty else { return nil }
        var latitude: Double = 0
        var longitude: Double = 0
        if let center = item.center {
            latitude = center.latitude ?? 0
            longitude = center.longitude ?? 0
        } else if let main = item.geocodes?.main {
            latitude = main.latitude ?? 0
            longitude = main.longitude ?? 0
        }
        return LocationResult(locationName: title, location: CLLocation(latitude: latitude, longitude: longitude))
    }
    
    /// Parse an autocomplete array containing only geo-typed FSQAutocompleteItems.
    public class func autocompleteGeoEntries(from array: [FSQAutocompleteItem]) -> [PlaceSearchResponse] {
        var results: [PlaceSearchResponse] = []
        for item in array where item.type == "geo" {
            let name = item.text ?? item.name ?? ""
            var lat: Double = 0
            var lng: Double = 0
            if let center = item.center {
                lat = center.latitude ?? 0
                lng = center.longitude ?? 0
            } else if let main = item.geocodes?.main {
                lat = main.latitude ?? 0
                lng = main.longitude ?? 0
            }
            let psr = PlaceSearchResponse(
                fsqID: "",
                name: name,
                categories: [],
                latitude: lat,
                longitude: lng,
                address: "",
                addressExtended: "",
                country: "",
                dma: "",
                formattedAddress: item.formatted_address ?? "",
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
    
    public class func autocompletePlaceSearchResponses(with response:FSQAutocompleteResponse) throws ->[PlaceSearchResponse] {
        var retVal = [PlaceSearchResponse]()
        guard let items = response.results, !items.isEmpty else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        for item in items {
            switch item.type {
            case "place":
                if let place = item.place {
                    let ident = "" // autocomplete place wrapper doesn't include fsq_id
                    let name = place.name ?? ""
                    let categories = [String]()
                    var latitude: Double = 0
                    var longitude: Double = 0
                    if let main = place.geocodes?.main {
                        if let lat = main.latitude { latitude = lat }
                        if let lon = main.longitude { longitude = lon }
                    }
                    let formattedAddress = place.location?.formatted_address ?? ""
                    let psr = PlaceSearchResponse(
                        fsqID: ident,
                        name: name,
                        categories: categories,
                        latitude: latitude,
                        longitude: longitude,
                        address: "",
                        addressExtended: "",
                        country: "",
                        dma: "",
                        formattedAddress: formattedAddress,
                        locality: "",
                        postCode: "",
                        region: "",
                        chains: [],
                        link: "",
                        childIDs: [],
                        parentIDs: []
                    )
                    retVal.append(psr)
                }
            case "address":
                let name = item.text ?? item.name ?? ""
                var latitude: Double = 0
                var longitude: Double = 0
                if let main = item.geocodes?.main {
                    if let lat = main.latitude { latitude = lat }
                    if let lon = main.longitude { longitude = lon }
                } else if let center = item.center {
                    if let lat = center.latitude { latitude = lat }
                    if let lon = center.longitude { longitude = lon }
                }
                let formatted = item.formatted_address ?? ""
                let psr = PlaceSearchResponse(
                    fsqID: "",
                    name: name,
                    categories: [],
                    latitude: latitude,
                    longitude: longitude,
                    address: "",
                    addressExtended: "",
                    country: "",
                    dma: "",
                    formattedAddress: formatted,
                    locality: "",
                    postCode: "",
                    region: "",
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
                retVal.append(psr)
            case "geo":
                let name = item.text ?? item.name ?? ""
                var latitude: Double = 0
                var longitude: Double = 0
                if let center = item.center {
                    if let lat = center.latitude { latitude = lat }
                    if let lon = center.longitude { longitude = lon }
                } else if let main = item.geocodes?.main {
                    if let lat = main.latitude { latitude = lat }
                    if let lon = main.longitude { longitude = lon }
                }
                let psr = PlaceSearchResponse(
                    fsqID: "",
                    name: name,
                    categories: [],
                    latitude: latitude,
                    longitude: longitude,
                    address: "",
                    addressExtended: "",
                    country: "",
                    dma: "",
                    formattedAddress: item.formatted_address ?? "",
                    locality: "",
                    postCode: "",
                    region: "",
                    chains: [],
                    link: "",
                    childIDs: [],
                    parentIDs: []
                )
                retVal.append(psr)
            default:
                continue
            }
        }
        return retVal
    }
    
    public class func placeSearchResponses(with response:FSQSearchResponse) throws ->[PlaceSearchResponse] {
        var retVal = [PlaceSearchResponse]()
        guard let results = response.results else { return retVal }
        for place in results {
            let ident = place.fsq_id ?? ""
            let name = place.name ?? ""
            var categories: [String] = []
            if let cats = place.categories {
                categories = cats.compactMap { $0.name }
            }
            var latitude: Double = 0
            var longitude: Double = 0
            if let main = place.geocodes?.main {
                if let lat = main.latitude { latitude = lat }
                if let lon = main.longitude { longitude = lon }
            } else if let roof = place.geocodes?.roof {
                if let lat = roof.latitude { latitude = lat }
                if let lon = roof.longitude { longitude = lon }
            }
            var address = ""
            var addressExtended = ""
            var country = ""
            var dma = ""
            var formattedAddress = ""
            var locality = ""
            var postCode = ""
            var region = ""
            if let loc = place.location {
                address = loc.address ?? ""
                addressExtended = loc.address_extended ?? ""
                country = loc.country ?? ""
                dma = loc.neighborhood?.values.first ?? ""
                formattedAddress = loc.formatted_address ?? ""
                locality = loc.locality ?? ""
                postCode = loc.postcode ?? ""
                region = loc.region ?? ""
            }
            let response = PlaceSearchResponse(
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
                chains: [],
                link: "",
                childIDs: [],
                parentIDs: []
            )
            if !ident.isEmpty || !name.isEmpty {
                retVal.append(response)
            }
        }
        return retVal
    }
    
    public class func placeDetailsResponse(with place: FSQPlace, for placeSearchResponse: PlaceSearchResponse, placePhotosResponses: [PlacePhotoResponse]? = nil, placeTipsResponses: [PlaceTipsResponse]? = nil, previousDetails: [PlaceDetailsResponse]? = nil) async throws -> PlaceDetailsResponse {
        
        var searchResponse = placeSearchResponse
        
        let placeFsqID = place.fsq_id ?? ""
        let placeName = place.name ?? ""
        let placeCategories = (place.categories ?? []).compactMap { $0.name }
        let placeLatitude = place.geocodes?.main?.latitude ?? place.geocodes?.roof?.latitude ?? 0
        let placeLongitude = place.geocodes?.main?.longitude ?? place.geocodes?.roof?.longitude ?? 0
        
        let formattedAddress = place.location?.formatted_address ?? ""
        let address = place.location?.address ?? ""
        let addressExtended = place.location?.address_extended ?? ""
        let country = place.location?.country ?? ""
        let dma = place.location?.neighborhood?.values.first ?? ""
        let locality = place.location?.locality ?? ""
        let postCode = place.location?.postcode ?? ""
        let region = place.location?.region ?? ""
        
        let needsUpgrade = searchResponse.fsqID.isEmpty
            || searchResponse.name.isEmpty
            || searchResponse.categories.isEmpty
            || searchResponse.latitude == 0
            || searchResponse.longitude == 0
            || searchResponse.formattedAddress.isEmpty
        
        if needsUpgrade {
            searchResponse = PlaceSearchResponse(
                fsqID: searchResponse.fsqID.isEmpty ? placeFsqID : searchResponse.fsqID,
                name: searchResponse.name.isEmpty ? placeName : searchResponse.name,
                categories: searchResponse.categories.isEmpty ? placeCategories : searchResponse.categories,
                latitude: (searchResponse.latitude == 0 && placeLatitude != 0) ? placeLatitude : searchResponse.latitude,
                longitude: (searchResponse.longitude == 0 && placeLongitude != 0) ? placeLongitude : searchResponse.longitude,
                address: searchResponse.address.isEmpty ? address : searchResponse.address,
                addressExtended: searchResponse.addressExtended.isEmpty ? addressExtended : searchResponse.addressExtended,
                country: searchResponse.country.isEmpty ? country : searchResponse.country,
                dma: searchResponse.dma.isEmpty ? dma : searchResponse.dma,
                formattedAddress: searchResponse.formattedAddress.isEmpty ? formattedAddress : searchResponse.formattedAddress,
                locality: searchResponse.locality.isEmpty ? locality : searchResponse.locality,
                postCode: searchResponse.postCode.isEmpty ? postCode : searchResponse.postCode,
                region: searchResponse.region.isEmpty ? region : searchResponse.region,
                chains: searchResponse.chains,
                link: searchResponse.link,
                childIDs: searchResponse.childIDs,
                parentIDs: searchResponse.parentIDs
            )
        }

        var description: String? = place.place_description
        if description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            description = nil
        }
        if description == nil, let previousDetails = previousDetails {
            for detail in previousDetails where detail.searchResponse.fsqID == searchResponse.fsqID {
                if let desc = detail.description, !desc.isEmpty {
                    description = desc
                    break
                }
            }
        }

        let tel = place.tel
        let fax = place.fax
        let email = place.email
        let website = place.website
        let socialMedia = place.social_media?.dictionaryValue.isEmpty == false ? place.social_media?.dictionaryValue : nil
        let verified = place.verified
        let hours = place.hours?.display
        let openNow = place.hours?.open_now
        let hoursPopular: [[String:Int]]? = nil
        let rating: Float = place.rating.map { Float($0) } ?? 0
        let stats: Bool? = nil
        let popularity: Float = place.popularity.map { Float($0) } ?? 0
        let price: Int? = place.price
        let dateClosed: String? = place.date_closed
        let tastes: [String]? = place.tastes
        let features: [String]? = nil

        let photoResponses = placePhotosResponses
        let tipsResponses = placeTipsResponses

        return PlaceDetailsResponse(
            searchResponse: searchResponse,
            photoResponses: photoResponses,
            tipsResponses: tipsResponses,
            description: description,
            tel: tel,
            fax: fax,
            email: email,
            website: website,
            socialMedia: socialMedia,
            verified: verified,
            hours: hours,
            openNow: openNow,
            hoursPopular: hoursPopular,
            rating: rating,
            stats: stats,
            popularity: popularity,
            price: price,
            dateClosed: dateClosed,
            tastes: tastes,
            features: features
        )
        
    }
    
    public class func placePhotoResponses(with response: FSQPhotosResponse, for placeID: String) -> [PlacePhotoResponse] {
        var retVal: [PlacePhotoResponse] = []
        for p in response {
            let ident = p.id ?? ""
            let createdAt = p.created_at ?? ""
            let height = Float(p.height ?? 0)
            let width = Float(p.width ?? 0)
            let prefix = p.prefix ?? ""
            let suffix = p.suffix ?? ""
            let resp = PlacePhotoResponse(id: ObjectIdentifier(NSString(string: ident)), placeIdent: placeID, ident: ident, createdAt: createdAt, height: height, width: width, classifications: [], prefix: prefix, suffix: suffix)
            retVal.append(resp)
        }
        return retVal
    }
    
    public class func placeTipsResponses(with response: [FSQTip], for placeID: String) -> [PlaceTipsResponse] {
        var retVal: [PlaceTipsResponse] = []
        var containsID = Set<String>()
        for tip in response {
            let ident = tip.id ?? ""
            let createdAt = tip.created_at ?? ""
            let text = tip.text ?? ""
            let resp = PlaceTipsResponse(id: ident, placeIdent: placeID, ident: ident, createdAt: createdAt, text: text)
            if !containsID.contains(resp.id) {
                containsID.insert(resp.id)
                retVal.append(resp)
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
