//
//  PlaceSearchResponse.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import Foundation

public struct PlaceSearchResponse: Equatable, Hashable {
    let uuid:UUID = UUID()
    let fsqID:String
    let name:String
    let categories:[String]
    let latitude:Double
    let longitude:Double
    let address:String
    let addressExtended:String
    let country:String
    let dma:String
    let formattedAddress:String
    let locality:String
    let postCode:String
    let region:String
    let chains:[String]
    let link:String
    let childIDs:[String]
    let parentIDs:[String]
}
