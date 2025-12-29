//
//  PlacePhotoResponse.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import Foundation

public struct PlacePhotoResponse: Codable, Identifiable, Sendable {
    public var id: String
    
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
    
    func photoUrl(width: Int? = nil, height: Int? = nil) -> URL? {
        if let width = width, let height = height {
            return URL(string: "\(prefix)\(width)x\(height)\(suffix)")
        }
        return URL(string: "\(prefix)original\(suffix)")
    }
}
