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
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var model:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider

    var body: some View {
        Map(initialPosition:.automatic, bounds: MapCameraBounds(minimumDistance: 500, maximumDistance: 250000)) {
                ForEach(model.filteredPlaceResults) { result in
                    if let placeResponse = result.placeResponse {
                        Marker(result.title, coordinate: CLLocationCoordinate2D(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                    }
                }
                if model.filteredPlaceResults.count == 0 {
                    let location = locationProvider.lastKnownLocation
                    Marker("Query Location", coordinate: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
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
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model

    return MapResultsView(chatHost: chatHost, model:model, locationProvider: locationProvider)
}
