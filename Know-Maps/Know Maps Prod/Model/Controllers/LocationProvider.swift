//
//  Location.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

@preconcurrency import Foundation
@preconcurrency import CoreLocation
public enum LocationProviderError : Error {
    case LocationManagerFailed
}

public class LocationProvider : NSObject, LocationProviderProtocol {
    // Note: Not @MainActor to allow nonisolated delegate callbacks.
    @MainActor public static let shared = LocationProvider()
    
    public let locationManager: CLLocationManager = CLLocationManager()
    
    public func isAuthorized() -> Bool {
#if os(visionOS) || os(iOS)
        return locationManager.authorizationStatus == .authorizedWhenInUse
#endif
#if os(macOS)
        return locationManager.authorizationStatus == .authorized
#endif
    }
    
    public func authorize() {
        locationManager.delegate = self
#if swift(>=5.9)
        // delegate callbacks are nonisolated; ensure we don't capture main actor
#endif
#if os(visionOS) || os(iOS)
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestLocation()
        }
#endif
#if os(macOS)
        if locationManager.authorizationStatus != .authorized {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
        } else {
            locationManager.requestLocation()
        }
#endif
    }
    
    @MainActor
    public func requestAuthorizationIfNeeded() async {
        // If already authorized, nothing to do
        if isAuthorized() { return }
        // Set delegate and request
        locationManager.delegate = self
#if os(visionOS) || os(iOS)
        locationManager.requestWhenInUseAuthorization()
#elseif os(macOS)
        locationManager.requestWhenInUseAuthorization()
#endif
        // Await a change in authorization via NotificationCenter
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var authorizedObserver: NSObjectProtocol?
            var deniedObserver: NSObjectProtocol?

            func cleanup() {
                if let authorizedObserver { NotificationCenter.default.removeObserver(authorizedObserver) }
                if let deniedObserver { NotificationCenter.default.removeObserver(deniedObserver) }
                authorizedObserver = nil
                deniedObserver = nil
            }

            authorizedObserver = NotificationCenter.default.addObserver(forName: Notification.Name("LocationProviderAuthorized"), object: nil, queue: .main) { _ in
                cleanup()
                continuation.resume()
            }

            deniedObserver = NotificationCenter.default.addObserver(forName: Notification.Name("LocationProviderDenied"), object: nil, queue: .main) { _ in
                cleanup()
                continuation.resume()
            }
        }
    }
    
    public func currentLocation(delegate:CLLocationManagerDelegate?)->CLLocation {
        if let delegate {
            locationManager.delegate = delegate
        }
        return locationManager.location ?? CLLocation.init(latitude:37.333562 , longitude:-122.004927)
    }
    
    @MainActor
    public func ensureAuthorizedAndRequestLocation() async {
        if !isAuthorized() {
            await requestAuthorizationIfNeeded()
        }
        locationManager.requestLocation()
    }
}


nonisolated extension LocationProvider : CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Hop to the main actor for UI/Notification work and accessing actor-isolated API if needed
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                print("Location Provider Authorized When in Use")
                NotificationCenter.default.post(name: Notification.Name("LocationProviderAuthorized"), object: nil)
            case .restricted, .denied:
                print("Location Provider Restricted or Denied")
                NotificationCenter.default.post(name: Notification.Name("LocationProviderDenied"), object: nil)
            case .notDetermined:
                print("Location Provider Not Determined")
                manager.requestWhenInUseAuthorization()
            default:
                break
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // No-op for now; add main-actor hop if updating UI/state
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Logging can be done directly; hop to main if needed
        print("Location Manager did fail with error:")
        print(error)
    }
}

