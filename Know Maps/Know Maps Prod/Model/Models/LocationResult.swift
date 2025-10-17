//
//  NearLocationResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/25/23.
//

import Foundation
import CoreLocation

public struct LocationResult : Identifiable, Equatable, Hashable, Sendable {
    public static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.locationName == rhs.locationName && lhs.location == rhs.location
    }
    
    public let id:String
    public var locationName:String
    public var location:CLLocation?
    
    public init(locationName: String, location: CLLocation? = nil) {
        self.id = UUID().uuidString
        self.locationName = locationName
        self.location = location
    }
    
    mutating public func replaceLocation(with location:CLLocation, name:String) {
        self.location = location
        self.locationName = name
    }
}
