//
//  MockLocationService.swift
//  Know MapsTests
//
//  Created for testing purposes
//

import Foundation
import CoreLocation
@testable import Know_Maps

@MainActor
final class MockLocationService: LocationService, @unchecked Sendable {
    
    var locationProvider: LocationProvider
    
    // Configurable responses
    var mockCurrentLocation: CLLocation
    var mockCurrentLocationName: String = "Mock Location"
    var mockPlacemarks: [CLPlacemark] = []
    var mockLocationResults: [LocationResult] = []
    
    init(locationProvider: LocationProvider = MockLocationProvider()) {
        self.locationProvider = locationProvider
        self.mockCurrentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    func currentLocation() -> CLLocation {
        return mockCurrentLocation
    }
    
    func currentLocationName() async throws -> String {
        return mockCurrentLocationName
    }
    
    func lookUpLocation(_ location: CLLocation) async throws -> [CLPlacemark] {
        return mockPlacemarks
    }
    
    func lookUpLocationName(name: String) async throws -> [CLPlacemark] {
        return mockPlacemarks
    }
}

// Mock LocationProvider to satisfy the dependency
final class MockLocationProvider: LocationProvider, @unchecked Sendable {
    
    var mockIsAuthorized: Bool = true
    var mockCurrentLocation: CLLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    
    override func isAuthorized() -> Bool {
        return mockIsAuthorized
    }
    
    override func requestAuthorizationIfNeeded() async {
        // No-op for testing
    }
    
    func currentLocation() -> CLLocation {
        return mockCurrentLocation
    }
}

