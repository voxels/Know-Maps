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
    @ObservedObject public var
model:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var selectedMapItem: String?
    var body: some View {
        Map(initialPosition:model.filteredPlaceResults.isEmpty ? .userLocation(fallback: .automatic) : .automatic, bounds: MapCameraBounds(minimumDistance: 1500, maximumDistance: 250000), interactionModes: .all, selection:$selectedMapItem, scope: nil) {
                ForEach(model.filteredPlaceResults) { result in
                    if let placeResponse = result.placeResponse {
                        Marker(result.title, coordinate: CLLocationCoordinate2D(latitude: placeResponse.latitude, longitude: placeResponse.longitude)).tag(placeResponse.fsqID)
                    }
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

    let locationProvider = LocationProvider()
    let cache = CloudCache()
    let chatHost = AssistiveChatHost(cache: cache)
    let model = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cache)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model

    return MapResultsView(chatHost: chatHost, model:model, locationProvider: locationProvider, selectedMapItem: .constant(nil))
}
