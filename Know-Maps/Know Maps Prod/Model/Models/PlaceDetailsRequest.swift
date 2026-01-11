//
//  PlaceDetailsRequest.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 4/1/23.
//

import Foundation


public struct PlaceDetailsRequest: Sendable {
    let fsqID:String
    let core:Bool
    let description:Bool
    let tel:Bool
    let fax:Bool
    let email:Bool
    let website:Bool
    let socialMedia:Bool
    let verified:Bool
    let hours:Bool
    let hoursPopular:Bool
    let rating:Bool
    let stats:Bool
    let popularity:Bool
    let price:Bool
    let menu:Bool
    let dateClosed:Bool = true
    let photos:Bool = true
    let tips:Bool = true
    let tastes:Bool
    let features:Bool
    let storeID:Bool = true
    
    public init(fsqID: String, core: Bool, description: Bool, tel: Bool, fax: Bool, email: Bool, website: Bool, socialMedia: Bool, verified: Bool, hours: Bool, hoursPopular: Bool, rating: Bool, stats: Bool, popularity: Bool, price: Bool, menu: Bool, tastes: Bool, features: Bool) {
        self.fsqID = fsqID
        self.core = core
        self.description = description
        self.tel = tel
        self.fax = fax
        self.email = email
        self.website = website
        self.socialMedia = socialMedia
        self.verified = verified
        self.hours = hours
        self.hoursPopular = hoursPopular
        self.rating = rating
        self.stats = stats
        self.popularity = popularity
        self.price = price
        self.menu = menu
        self.tastes = tastes
        self.features = features
    }
}
