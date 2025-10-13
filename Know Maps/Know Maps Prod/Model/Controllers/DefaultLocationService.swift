//
//  LocationServices.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/7/24.
//

@preconcurrency import CoreLocation

// MARK: - Concrete Location Service
public final class DefaultLocationService: NSObject, LocationService {
    
    // Debounce support
    private var reverseGeocodeTask: Task<[CLPlacemark], Error>? = nil
    private var forwardGeocodeTask: Task<[CLPlacemark], Error>? = nil
    private let geocodeDebounceInterval: Duration = .milliseconds(300)
    
    // Equality / caching support
    private var lastReverseGeocodeLocation: CLLocation? = nil
    private var lastReverseGeocodeResult: [CLPlacemark]? = nil
    private var lastForwardGeocodeName: String? = nil
    private var lastForwardGeocodeResult: [CLPlacemark]? = nil
    private let reverseGeocodeEqualityToleranceMeters: CLLocationDistance = 10
    
    public let locationProvider:LocationProvider
    
    private let geocoder = CLGeocoder()
    
    public init(locationProvider:LocationProvider) {
        self.locationProvider = locationProvider
    }
    
    public func currentLocationName() async throws -> String? {
        let placemarks = try await debouncedReverseGeocode(locationProvider.currentLocation(delegate: self))
        return placemarks.first?.name
    }
    
    public func currentLocation() -> CLLocation {
        return locationProvider.currentLocation(delegate:self)
    }
    
    public func lookUpLocation(_ location: CLLocation) async throws -> [CLPlacemark] {
        return try await debouncedReverseGeocode(location)
    }
    
    public func lookUpLocationName(name: String) async throws -> [CLPlacemark] {
        return try await debouncedForwardGeocode(name)
    }
    
    // MARK: - Debounced Geocoding
    private func debouncedReverseGeocode(_ location: CLLocation) async throws -> [CLPlacemark] {
        // Return cached result if location is effectively unchanged
        if let lastLoc = lastReverseGeocodeLocation,
           let cached = lastReverseGeocodeResult,
           lastLoc.distance(from: location) <= reverseGeocodeEqualityToleranceMeters {
            return cached
        }
        // Cancel any in-flight reverse geocode task
        reverseGeocodeTask?.cancel()
        let task = Task<[CLPlacemark], Error> {
            // Small debounce window to coalesce rapid calls
            try await Task.sleep(for: geocodeDebounceInterval)
            return try await geocoder.reverseGeocodeLocation(location)
        }
        reverseGeocodeTask = task
        do {
            let result = try await task.value
            // Cache input and result for equality short-circuiting
            lastReverseGeocodeLocation = location
            lastReverseGeocodeResult = result
            return result
        } catch is CancellationError {
            // Propagate cancellation if the caller cares
            throw CancellationError()
        } catch {
            throw error
        }
    }

    private func debouncedForwardGeocode(_ name: String) async throws -> [CLPlacemark] {
        // Return cached result if name is unchanged
        if let lastName = lastForwardGeocodeName,
           let cached = lastForwardGeocodeResult,
           lastName == name {
            return cached
        }
        // Cancel any in-flight forward geocode task
        forwardGeocodeTask?.cancel()
        let task = Task<[CLPlacemark], Error> {
            // Small debounce window to coalesce rapid calls
            try await Task.sleep(for: geocodeDebounceInterval)
            return try await geocoder.geocodeAddressString(name)
        }
        forwardGeocodeTask = task
        do {
            let result = try await task.value
            // Cache input and result for equality short-circuiting
            lastForwardGeocodeName = name
            lastForwardGeocodeResult = result
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }
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

