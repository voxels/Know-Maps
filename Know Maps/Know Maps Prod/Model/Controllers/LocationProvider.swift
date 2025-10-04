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
#if os(visionOS) || os(iOS)
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
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
    
    public func currentLocation(delegate:CLLocationManagerDelegate?)->CLLocation {
        if let delegate {
            locationManager.delegate = delegate
        }
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
        return locationManager.location ?? CLLocation.init(latitude:37.333562 , longitude:-122.004927)
    }
}
