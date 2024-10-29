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
    @Environment(\.dismiss) var dismiss

    @Binding public var model:ChatResultViewModel
    @Binding public var modelController:DefaultModelController
    @Binding public var selectedMapItem: String?
    @Binding public var cameraPosition:MapCameraPosition
    @Binding public var showMapsResultViewSheet:Bool
    
    var body: some View {
        VStack {
            HStack {
                Button(action:{
                    dismiss()
                }, label:{
                    Text("Dismiss")
                }).padding()
                Spacer()
            }
            Map(position: $cameraPosition, interactionModes: .all, selection: $selectedMapItem) {
                ForEach(modelController.mapPlaceResults) { result in
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
            .padding(32)
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
    }
    
    private func updateCamera(for locationResult: UUID) {
        withAnimation {
            cameraPosition = .automatic
        }
    }
}
