//
//  UserCachedRecord.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/3/24.
//

import Foundation

public struct UserCachedRecord : Codable, Equatable {
    var recordId:String
    let group:String
    let identity:String
    let title:String
    let icons:String
    
    mutating public func setRecordId(to string:String) {
        recordId = string
    }
}
