//
//  LocationServices.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

@preconcurrency import CoreLocation

// MARK: - Concrete Location Service
public final class DefaultLocationService: NSObject, LocationService {
    
    public let locationProvider:LocationProvider
    
    private let geocoder = CLGeocoder()
    
    public init(locationProvider:LocationProvider) {
        self.locationProvider = locationProvider
    }
    
    public func currentLocationName() async throws -> String? {
        return try await lookUpLocation( locationProvider.currentLocation(delegate:self)).first?.name
    }
    
    public func currentLocation() -> CLLocation {
        return locationProvider.currentLocation(delegate:self)
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


extension DefaultLocationService : CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch locationProvider.locationManager.authorizationStatus {
        case .authorizedAlways:
            fallthrough
        case .authorizedWhenInUse:  // Location services are available.
            print("Location Provider Authorized When in Use")
            NotificationCenter.default.post(name: Notification.Name("LocationProviderAuthorized"), object: nil)
            break
        case .restricted, .denied:  // Location services currently unavailable.
            print("Location Provider Restricted or Denied")
            NotificationCenter.default.post(name: Notification.Name("LocationProviderDenied"), object: nil)
            break
        case .notDetermined:        // Authorization not determined yet.
            print("Location Provider Not Determined")
            locationProvider.locationManager.requestWhenInUseAuthorization()
            break
        default:
            break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager did fail with error:")
        print(error)
    }
}

