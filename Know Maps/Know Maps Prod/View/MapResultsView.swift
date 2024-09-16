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
        let initialPosition:MapCameraPosition = model.selectedDestinationLocationChatResult != nil && model.placeResults.isEmpty ? .camera(MapCamera(centerCoordinate: model.locationChatResult(for: model.selectedDestinationLocationChatResult!)!.location!.coordinate, distance: 250000))   : .automatic
        Map(initialPosition: initialPosition, bounds: MapCameraBounds(minimumDistance: 5000, maximumDistance: 250000), interactionModes: .all, selection:$selectedMapItem, scope: nil) {
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
            .mapStyle(.imagery)
            .cornerRadius(16)
            .padding(16)
    }
}

#Preview {

    let locationProvider = LocationProvider()

    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel

    return MapResultsView(chatHost: chatHost, model:chatModel, locationProvider: locationProvider, selectedMapItem: .constant(nil))
}
