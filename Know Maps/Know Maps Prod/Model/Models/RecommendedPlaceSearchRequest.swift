//
//  RecommendedPlaceSearchRequest.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/24/24.
//

import Foundation

public struct RecommendedPlaceSearchRequest {
    let query:String
    let ll:String?
    var radius:Int = 20000
    let categories:String?
    var minPrice:Int = 1
    var maxPrice:Int = 4
    let openNow:Bool?
    let nearLocation:String?
    var limit:Int = 50
    var offset:Int = 0
    var tags:AssistiveChatHostTaggedWord
    
    mutating func updateOffset(with offset:Int){
        self.offset = offset
    }
}
