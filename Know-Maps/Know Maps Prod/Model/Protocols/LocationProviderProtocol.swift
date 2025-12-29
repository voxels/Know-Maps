//
//  LocationProviderProtocol.swift
//  Know Maps
//

import Foundation
import CoreLocation

@MainActor
public protocol LocationProviderProtocol: CLLocationManagerDelegate, Sendable {
    func isAuthorized() -> Bool
    func authorize()
    func requestAuthorizationIfNeeded() async
    func currentLocation(delegate: CLLocationManagerDelegate?) -> CLLocation
    func ensureAuthorizedAndRequestLocation() async
}
