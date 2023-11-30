//
//  PlaceDirectionsControlsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/24/23.
//

import SwiftUI
import MapKit

struct PlaceDirectionsControlsView: View {
    
    @ObservedObject public var model:PlaceDirectionsViewModel
    @Binding public var showLookAroundScene:Bool
    
    public enum RawTransportType : String {
        case Walking
        case Transit
        case Automobile
    }
    
    var body: some View {
        HStack {
            Spacer()
            if !showLookAroundScene {
                Picker("Transport Type", selection: $model.rawTransportType) {
                    Text(RawTransportType.Walking.rawValue).tag(0)
                    Text(RawTransportType.Automobile.rawValue).tag(2)
                }
                .padding(4)
            }
            if showLookAroundScene {
                Button("Directions", systemImage: "map.fill") {
                    showLookAroundScene.toggle()
                }
                .padding(4)
            } else {
                Button("Look Around", systemImage: "binoculars.fill") {
                    showLookAroundScene.toggle()
                }
                .padding(4)
            }
            
            if let source = model.source, let destination = model.destination {
                let launchOptions = model.appleMapsLaunchOptions()
                Button {
                    MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                } label: {
                    Label("Apple Maps", systemImage: "apple.logo")
                }
            }

            
            if let url = URL(string:"") {
                Link(destination:url) {
                    Label("Apple Maps", systemImage: "apple.logo")
                }
            }
            Spacer()
        }
    }
}

#Preview {
    let model = PlaceDirectionsViewModel()
    return PlaceDirectionsControlsView(model: model, showLookAroundScene: .constant(false))
}
