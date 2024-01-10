//
//  PlaceDirectionsControlsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/24/23.
//

import SwiftUI
import MapKit

struct PlaceDirectionsControlsView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
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
                    Picker("Route Start Location", selection:$model.rawLocationIdent) {
                        ForEach(chatModel.filteredLocationResults, id:\.self) { result in
                            Text(result.locationName).tag(result.id.uuidString)
                        }
                    }
                    Picker("Transport Type", selection: $model.rawTransportType) {
                        Text(RawTransportType.Walking.rawValue).tag(0)
                        Text(RawTransportType.Automobile.rawValue).tag(2)
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
                Spacer()
            }
        }
}

#Preview {
    let model = PlaceDirectionsViewModel()
    let locationProvider = LocationProvider()

    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return PlaceDirectionsControlsView(chatModel: chatModel, model: model, showLookAroundScene: .constant(false))
}
