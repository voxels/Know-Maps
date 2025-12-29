//
//  MockLocationService.swift
//  knowmapsTests
//

import Foundation
import CoreLocation
@testable import Know_Maps

public final class MockLocationProvider: NSObject, LocationProviderProtocol {
    public var mockLocation: CLLocation = CLLocation(latitude: 37.333562, longitude: -122.004927)
    public var mockAuthorized: Bool = true
    
    public func isAuthorized() -> Bool { mockAuthorized }
    public func authorize() {}
    public func requestAuthorizationIfNeeded() async {}
    public func currentLocation(delegate: CLLocationManagerDelegate?) -> CLLocation { mockLocation }
    public func ensureAuthorizedAndRequestLocation() async {}
}

@MainActor
public final class MockLocationService: LocationService {
    public var locationProvider: LocationProviderProtocol
    public var mockPlacemarks: [CLPlacemark] = []
    public var lastLookedUpName: String?
    
    public init(locationProvider: LocationProviderProtocol? = nil) {
        self.locationProvider = locationProvider ?? MockLocationProvider()
    }
    
    public func currentLocationName() async throws -> String {
        return mockPlacemarks.first?.name ?? "Mock Location"
    }
    
    public func currentLocation() -> CLLocation {
        return locationProvider.currentLocation(delegate: nil)
    }
    
    public func lookUpLocation(_ location: CLLocation) async throws -> [CLPlacemark] {
        return mockPlacemarks
    }
    
    public func lookUpLocationName(name: String) async throws -> [CLPlacemark] {
        lastLookedUpName = name
        return mockPlacemarks
    }
}
