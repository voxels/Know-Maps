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
    
    public class func autocompleteTastesResponses(with response: FSQTastesResponse) throws -> [String] {
        return (response.tastes ?? []).compactMap { $0.text }
    }
    
    // Legacy V2 formatters kept only for active sessions (Recommend/Related)
    // TODO: Modernize Recommended/Related to V3 and remove these.
    
    // MARK: - Geo helpers
    
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
            let resp = PlacePhotoResponse(id: ident, placeIdent: placeID, ident: ident, createdAt: createdAt, height: height, width: width, classifications: [], prefix: prefix, suffix: suffix)
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
        
    public class func placeChatResults(for intent:AssistiveChatHostIntent, place:PlaceSearchResponse, section:PersonalizedSearchSection, list:String, index:Int, rating:Double, details:PlaceDetailsResponse?)->[ChatResult] {
        return [PlaceResponseFormatter.chatResult(index: index, title: place.name, section:section, list:list, rating:rating, placeResponse: place, placeDetailsResponse: details)]
    }
    
    public class func chatResult(index:Int, title:String, section:PersonalizedSearchSection, list:String, rating:Double, placeResponse:PlaceSearchResponse, placeDetailsResponse:PlaceDetailsResponse?)->ChatResult {
        let result = ChatResult(index: index, identity: placeResponse.fsqID, title:title, list:list, icon: "", rating: rating, section:section, placeResponse: placeResponse, placeDetailsResponse:placeDetailsResponse)
                        
        return result
    }
}
