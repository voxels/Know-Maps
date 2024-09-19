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
    @Binding public var selectedMapItem: String?
    @Binding public var cameraPosition:MapCameraPosition
    
    var body: some View {
        
        Map(position: $cameraPosition, interactionModes: .all, selection: $selectedMapItem) {
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
            .task {
                cameraPosition = model.selectedDestinationLocationChatResult != nil ? .camera(MapCamera(centerCoordinate: model.locationChatResult(for: model.selectedDestinationLocationChatResult!)?.location?.coordinate ?? locationProvider.currentLocation()!.coordinate, distance: 50000)) : .automatic
            }
            .onChange(of: model.selectedDestinationLocationChatResult) { oldValue, newValue in
                if let newLocation = newValue {
                    updateCamera(for: newLocation)
                }
            }
    }
    
    private func updateCamera(for locationResult: UUID) {
        if let location = model.locationChatResult(for: locationResult)?.location?.coordinate {
            withAnimation {
                cameraPosition = .camera(MapCamera(centerCoordinate: location, distance: 50000))
            }
        }
    }
}
