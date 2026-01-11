//
//  PlaceSearchRequest.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/19/23.
//

import Foundation

public struct PlaceSearchRequest: Sendable {
    public let query:String
    public let ll:String?
    public var radius:Int = 20000
    public let categories:String?
    public let fields:String?
    public var minPrice:Int = 1
    public var maxPrice:Int = 4
    public let openAt:String?
    public let openNow:Bool?
    public let nearLocation:String?
    public let sort:String?
    public var limit:Int = 50
    public var offset:Int = 0

    public init(query: String, ll: String? = nil, radius: Int = 20000, categories: String? = nil, fields: String? = nil, minPrice: Int = 1, maxPrice: Int = 4, openAt: String? = nil, openNow: Bool? = nil, nearLocation: String? = nil, sort: String? = nil, limit: Int = 50, offset: Int = 0) {
        self.query = query
        self.ll = ll
        self.radius = radius
        self.categories = categories
        self.fields = fields
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.openAt = openAt
        self.openNow = openNow
        self.nearLocation = nearLocation
        self.sort = sort
        self.limit = limit
        self.offset = offset
    }
}
