//
//  Location.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/20/23.
//

import Foundation
import CoreLocation

public enum LocationProviderError : Error {
    case LocationManagerFailed
}

open class LocationProvider : NSObject, ObservableObject  {
    private var locationManager: CLLocationManager = CLLocationManager()
    private var retryCount = 0
    private var maxRetries = 2
    @Published public var lastKnownLocation:CLLocation?
    public func authorize() {
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        
        locationManager.delegate = self
        locationManager.requestLocation()
    }
    
    public func currentLocation()->CLLocation? {
        if lastKnownLocation == nil {
            if locationManager.authorizationStatus != .authorizedWhenInUse {
                authorize()
            }
            locationManager.delegate = self
            locationManager.requestLocation()
            lastKnownLocation = locationManager.location
            return locationManager.location
        } else {
            locationManager.delegate = self
            locationManager.requestLocation()
            return lastKnownLocation
        }
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
        self.lastKnownLocation = locations.last
        print("Last Known Location:\(String(describing: lastKnownLocation?.coordinate.latitude)), \(String(describing: lastKnownLocation?.coordinate.longitude))")
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager did fail with error:")
        print(error)
        if retryCount >= maxRetries {
            return
        }
        locationManager.requestLocation()
        retryCount += 1
    }
}
