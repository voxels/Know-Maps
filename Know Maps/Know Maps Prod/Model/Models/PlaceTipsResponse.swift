//
//  PlaceTipsResponse.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import Foundation

public struct PlaceTipsResponse : Identifiable, Hashable  {
    public var id: UUID
    let placeIdent:String
    let ident:String
    let createdAt:String
    let text:String
}
