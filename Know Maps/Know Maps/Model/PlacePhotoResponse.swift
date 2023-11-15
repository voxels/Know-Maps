//
//  PlacePhotoResponse.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import Foundation

public struct PlacePhotoResponse {
    let placeIdent:String
    let ident:String
    let createdAt:String
    let height:Float
    let width:Float
    var aspectRatio:Float {
        get {
            return width/height
        }
    }
    let classifications:[String]
    let prefix:String
    let suffix:String
    
    func photoUrl() ->URL? {
        return URL(string:"\(prefix)\(Int(floor(width)))x\(Int(floor(height)))\(suffix)")
    }
}
