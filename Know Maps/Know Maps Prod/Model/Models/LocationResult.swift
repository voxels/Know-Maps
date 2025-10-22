//
//  NearLocationResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/25/23.
//

import Foundation
import CoreLocation

public class LocationResult : Identifiable, Equatable, Hashable, Sendable {
    public static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.locationName == rhs.locationName && lhs.location == rhs.location
    }
    
    public let id:String
    public let locationName:String
    public let location:CLLocation
    
    public init(locationName: String, location: CLLocation) {
        self.id = UUID().uuidString
        self.locationName = locationName
        self.location = location
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
