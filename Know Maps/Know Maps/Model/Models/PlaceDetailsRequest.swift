//
//  PlaceDetailsRequest.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 4/1/23.
//

import Foundation


public struct PlaceDetailsRequest {
    let fsqID:String
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
}
