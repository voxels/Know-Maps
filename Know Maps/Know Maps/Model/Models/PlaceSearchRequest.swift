//
//  PlaceSearchRequest.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import Foundation
import CoreLocation

public struct PlaceSearchRequest {
    let query:String
    let ll:String?
    var radius:Int = 3000
    let categories:String?
    let fields:String?
    var minPrice:Int = 1
    var maxPrice:Int = 4
    let openAt:String?
    let openNow:Bool?
    let nearLocation:String?
    let sort:String?
    var limit:Int = 30
}
