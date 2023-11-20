//
//  MapResultsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct MapResultsView: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var model:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider

    var body: some View {
        Map(initialPosition:.automatic, bounds: MapCameraBounds(minimumDistance: 500, maximumDistance: 100000)) {
                ForEach(model.filteredPlaceResults) { result in
                    if let placeResponse = result.placeResponse {
                        Marker(result.title, coordinate: CLLocationCoordinate2D(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                    }
                }
                if model.filteredPlaceResults.count == 0, let location = locationProvider.lastKnownLocation {
                    Marker("Current Location", coordinate: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                }
            }
            .mapControls {
                MapPitchToggle()
                MapUserLocationButton()
                MapCompass()
              }
            .mapStyle(.hybrid(elevation: .automatic,
                               pointsOfInterest: .including([.publicTransport]),
                               showsTraffic: false))
            .onChange(of: locationProvider.mostRecentLocations) { oldValue, newValue in
                if let lastLocation = newValue.last, let knownLocation = locationProvider.lastKnownLocation, knownLocation.coordinate.latitude == LocationProvider.defaultLocation.coordinate.latitude && knownLocation.coordinate.longitude == LocationProvider.defaultLocation.coordinate.longitude {
                    locationProvider.queryLocation = lastLocation
                }
            }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model

    return MapResultsView(chatHost: chatHost, model: model, locationProvider: locationProvider)
}
