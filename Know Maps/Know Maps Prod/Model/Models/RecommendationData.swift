//
//  RecommendationData.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/9/24.
//

import Foundation

public struct RecommendationData : Identifiable, Hashable, Codable, Equatable {
    public var id:UUID = UUID()
    var recordId:String
    var identity:String
    var attributes:[String]
    var reviews:[String]
    var attributeRatings:[String:Double]
    
    mutating public func setRecordId(to string:String) {
        recordId = string
    }
}
