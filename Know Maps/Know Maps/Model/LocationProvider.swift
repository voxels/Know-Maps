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
    public static let defaultLocation:CLLocation = CLLocation(latitude: 40.730610, longitude: -73.935242)
    @Published public var queryLocation:CLLocation = LocationProvider.defaultLocation
    @Published public var mostRecentLocations = [CLLocation]()
    public var lastKnownLocation:CLLocation {
        get {
            return queryLocation
        }
    }
    
    public var lastKnownLocationName:String {
        return "Query Location"
    }
    
    public func authorize() {
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        
        locationManager.delegate = self
        locationManager.requestLocation()
    }
    
    public func currentLocation()->CLLocation? {
        if locationManager.authorizationStatus != .authorizedWhenInUse {
            authorize()
        }
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
        guard let lastLocation = locations.last else {
            return
        }
        
        if queryLocation.coordinate.latitude == LocationProvider.defaultLocation.coordinate.latitude && queryLocation.coordinate.longitude == LocationProvider.defaultLocation.coordinate.longitude {
            Task { @MainActor in
                queryLocation = lastLocation
            }
        }
        
        if let lastRecentLocation = mostRecentLocations.last {
            if lastRecentLocation.coordinate.latitude == lastLocation.coordinate.latitude && lastRecentLocation.coordinate.longitude == lastLocation.coordinate.longitude {
                return
            }
        }
        
        Task { @MainActor in
            mostRecentLocations = locations
            print("Last Known Location:\(String(describing: locations.last?.coordinate.latitude)), \(String(describing: locations.last?.coordinate.longitude))")
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager did fail with error:")
        print(error)
    }
}

