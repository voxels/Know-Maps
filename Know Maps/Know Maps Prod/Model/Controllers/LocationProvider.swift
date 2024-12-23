//
//  Location.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import Foundation
@preconcurrency import CoreLocation
public enum LocationProviderError : Error {
    case LocationManagerFailed
}


public final class LocationProvider : NSObject, Sendable  {
    private let locationManager: CLLocationManager = CLLocationManager()
    
    public func isAuthorized() -> Bool {
#if os(visionOS) || os(iOS)
        return locationManager.authorizationStatus == .authorizedWhenInUse
#endif
#if os(macOS)
        return locationManager.authorizationStatus == .authorized
#endif
    }
    
    public func authorize() {
#if os(visionOS) || os(iOS)
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
            locationManager.delegate = self
            locationManager.requestLocation()
        }
#endif
#if os(macOS)
        if locationManager.authorizationStatus != .authorized {
            locationManager.requestWhenInUseAuthorization()
            locationManager.delegate = self
            locationManager.requestLocation()
        } else {
            locationManager.delegate = self
            locationManager.requestLocation()
        }
#endif
    }
    
    public func currentLocation()->CLLocation? {
#if os(visionOS) || os(iOS)
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            authorize()
        }
#endif
#if os(macOS)
        if locationManager.authorizationStatus != .authorizedAlways {
            authorize()
        }
#endif
        locationManager.delegate = self
        locationManager.requestLocation()
        return locationManager.location
    }
    
    
}

extension LocationProvider : CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch locationManager.authorizationStatus {
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
            locationManager.requestWhenInUseAuthorization()
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

