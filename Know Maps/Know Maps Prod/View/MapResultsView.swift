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
    @ObservedObject public var model:ChatResultViewModel
    @ObservedObject public var modelController:DefaultModelController
    @State private var selectedMapItem: String?
    @Binding public var cameraPosition:MapCameraPosition
    
    var body: some View {
        
        Map(position: $cameraPosition, interactionModes: .all, selection: $selectedMapItem) {
            ForEach(modelController.filteredPlaceResults) { result in
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
                cameraPosition = .automatic
            }
            .onChange(of: modelController.selectedDestinationLocationChatResult) { oldValue, newValue in
                if let newLocation = newValue {
                    updateCamera(for: newLocation)
                } else {
                    updateCamera(for: modelController.currentLocationResult.id)
                }
            }
    }
    
    private func updateCamera(for locationResult: UUID) {
        withAnimation {
            cameraPosition = .automatic
        }
    }
}
