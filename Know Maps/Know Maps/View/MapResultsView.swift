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
        Map(initialPosition: .userLocation(followsHeading: true, fallback: .automatic), bounds: MapCameraBounds(minimumDistance: 500, maximumDistance: 5000)) {
                ForEach(model.filteredPlaceResults) { result in
                    if let placeResponse = result.placeResponse {
                        Marker(result.title, coordinate: CLLocationCoordinate2D(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                    }
                }

            }
            .mapControls {
                MapPitchToggle()
                MapUserLocationButton()
                MapCompass()
              }
            .mapStyle(.hybrid(elevation: .realistic,
                               pointsOfInterest: .including([.publicTransport]),
                               showsTraffic: true))
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
