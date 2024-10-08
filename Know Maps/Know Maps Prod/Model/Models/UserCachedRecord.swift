//
//  UserCachedRecord.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/3/24.
//

import Foundation

public struct UserCachedRecord : Identifiable, Hashable, Codable, Equatable {
    public var id:UUID = UUID()
    var recordId:String
    let group:String
    let identity:String
    let title:String
    let icons:String
    let list:String
    let section:String
    let rating:Int
    
    mutating public func setRecordId(to string:String) {
        recordId = string
    }
}
