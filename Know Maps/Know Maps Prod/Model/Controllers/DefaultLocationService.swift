//
//  LocationServices.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

@preconcurrency import CoreLocation

// MARK: - Concrete Location Service
public final class DefaultLocationService: LocationService {
    
    public let locationProvider:LocationProvider
    
    private let geocoder = CLGeocoder()
    
    public init(locationProvider:LocationProvider) {
        self.locationProvider = locationProvider
    }
    
    public func currentLocationName() async throws -> String? {
        return try await lookUpLocation( locationProvider.currentLocation()).first?.name
    }
    
    public func currentLocation() -> CLLocation? {
        return locationProvider.currentLocation()
    }
    
    public func lookUpLocation(_ location: CLLocation) async throws -> [CLPlacemark] {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks
    }
    
    public func lookUpLocationName(name: String) async throws -> [CLPlacemark] {
        let placemarks = try await geocoder.geocodeAddressString(name)
        return placemarks
    }
}
