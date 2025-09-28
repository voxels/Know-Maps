//
//  LocationService.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

import Foundation
import CoreLocation

// MARK: - Location Service Protocol
public protocol LocationService : Sendable {
    func currentLocationName() async throws -> String?
    func currentLocation() -> CLLocation
    func lookUpLocation(_ location: CLLocation) async throws -> [CLPlacemark]
    func lookUpLocationName(name: String) async throws -> [CLPlacemark]
}
