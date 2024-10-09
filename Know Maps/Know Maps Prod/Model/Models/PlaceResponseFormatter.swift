//
//  PlaceResponseFormatter.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation

public enum PlaceResponseFormatterError : Error {
    case InvalidRawResponseType
}

open class PlaceResponseFormatter {
    
    public class func autocompleteTastesResponses(with response:[String:Any]) throws ->[TasteAutocompleteResponse] {
        var retval = [TasteAutocompleteResponse]()
        
            if let results = response["tastes"] as? [NSDictionary] {
                for result in results {
                    var id:String = ""
                    var text:String = ""
                    
                    if let rawId = result["id"] as? String {
                        id = rawId
                    }
                    
                    if let rawText = result["text"] as? String {
                        text = rawText
                    }
                    
                    let taste = TasteAutocompleteResponse(id:id, text:text)
                    retval.append(taste)
                }
        }
        
        return retval
    }
    
    public class func autocompleteRecommendedPlaceSearchResponses(with response:[String:Any]) throws ->[RecommendedPlaceSearchResponse] {
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
        var retval = [RecommendedPlaceSearchResponse]()
        
        guard response.keys.count > 0 else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        if let resultsDict = response["group"] as? NSDictionary {
            if  let results = resultsDict["results"] as? [NSDictionary] {
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
        
        
        return retval
        
    }
    
    public class func relatedPlaceSearchResponses(with response:[String:Any]) throws ->[RecommendedPlaceSearchResponse] {
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
    
    
    public class func placeSearchResponses(from recommendedPlaceSearchResponses:[RecommendedPlaceSearchResponse])->[PlaceSearchResponse]{
        var retVal = [PlaceSearchResponse]()
        
        for response in recommendedPlaceSearchResponses {
            retVal.append(PlaceSearchResponse(fsqID: response.fsqID, name: response.name, categories: response.categories, latitude: response.latitude, longitude: response.longitude, address: response.address, addressExtended: response.formattedAddress, country: response.country, dma: response.neighborhood, formattedAddress: response.formattedAddress, locality: response.city, postCode: response.postCode, region: response.state, chains: [], link: "", childIDs: [], parentIDs: []))
        }
                
        return retVal
    }
    
    public class func autocompletePlaceSearchResponses(with response:[String:Any]) throws ->[PlaceSearchResponse] {
        var retVal = [PlaceSearchResponse]()
        
        guard response.keys.count > 0 else {
            throw PlaceResponseFormatterError.InvalidRawResponseType
        }
        
        if let results = response["results"] as? [NSDictionary] {
            
            for resultDict in results {
                if let result = resultDict["place"] as? NSDictionary {
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
        }
        
        return retVal
    }
    
    public class func placeSearchResponses(with response:Any) throws ->[PlaceSearchResponse] {
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
        var menu:AnyObject? = nil
        if let rawMenu = response["menu"] as? AnyObject {
            menu = rawMenu
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
        
        return PlaceDetailsResponse(searchResponse: searchResponse, photoResponses: photoResponses, tipsResponses: tipsResponses, description: description, tel: tel, fax: fax, email: email, website: website, socialMedia: socialMedia, verified: verified, hours: hours, openNow: openNow, hoursPopular: hoursPopular, rating: rating, stats: stats, popularity: popularity, price: price, menu: menu, dateClosed: dateClosed, tastes: tastes, features: features)
        
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
            
            let response = PlaceTipsResponse(id:UUID(), placeIdent:placeID, ident: ident, createdAt: createdAt, text: text)
            if !containsID.contains(response.id.uuidString){
                containsID.insert(response.id.uuidString)
                retVal.append(response)                
            }
        }
        return retVal
    }
        
    public class func placeChatResults(for intent:AssistiveChatHostIntent, place:PlaceSearchResponse, section:PersonalizedSearchSection, list:String, rating:Double, details:PlaceDetailsResponse?, recommendedPlaceResponse:RecommendedPlaceSearchResponse? = nil)->[ChatResult] {
        return [PlaceResponseFormatter.chatResult(title: place.name, section:section, list:list, rating:rating, placeResponse: place, placeDetailsResponse: details, recommendedPlaceResponse: recommendedPlaceResponse)]
    }
    
    public class func chatResult(title:String, section:PersonalizedSearchSection, list:String, rating:Double, placeResponse:PlaceSearchResponse?, placeDetailsResponse:PlaceDetailsResponse?, recommendedPlaceResponse:RecommendedPlaceSearchResponse? = nil)->ChatResult {
        let result = ChatResult(title:title, list:list, icon: "", rating: rating, section:section, placeResponse: placeResponse, recommendedPlaceResponse: recommendedPlaceResponse, placeDetailsResponse:placeDetailsResponse)
                        
        return result
    }
}
