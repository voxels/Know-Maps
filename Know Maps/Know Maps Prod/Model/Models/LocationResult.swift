//
//  NearLocationResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/25/23.
//

import Foundation
import CoreLocation

public final class LocationResult : Identifiable, Equatable, Hashable, Sendable {
    
    public let id:String
    public let locationName:String
    public let location:CLLocation
    public let formattedAddress:String?
    
    public init(locationName: String, location: CLLocation, formattedAddress: String? = nil) {
        self.id = UUID().uuidString
        self.locationName = locationName
        self.location = location
        self.formattedAddress = formattedAddress
    }
    
    static public func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
