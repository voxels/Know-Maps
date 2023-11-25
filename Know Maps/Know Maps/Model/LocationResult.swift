//
//  NearLocationResult.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/25/23.
//

import Foundation
import CoreLocation

public struct LocationResult : Identifiable, Equatable, Hashable {
    public static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id = UUID()
    public let locationName:String
    public let location:CLLocation?
}
