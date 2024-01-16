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
#if os(iOS)
        VStack {
            HStack {
                if !showLookAroundScene {
                    Spacer()
                    Picker("Route Start Location", selection:$model.rawLocationIdent) {
                        ForEach(chatModel.filteredLocationResults, id:\.self) { result in
                            Text(result.locationName).tag(result.id.uuidString)
                        }
                    }.foregroundStyle(.primary)
                    Spacer()
                    Picker("Transport Type", selection: $model.rawTransportType) {
                        Text(RawTransportType.Walking.rawValue).tag(0)
                        Text(RawTransportType.Automobile.rawValue).tag(2)
                    }.foregroundStyle(.primary)
                    Spacer()
                }
            }
            HStack {
                Spacer()
                if let source = model.source, let destination = model.destination {
                    let launchOptions = model.appleMapsLaunchOptions()
                    Button("Apple Maps", systemImage: "apple.logo") {
                        MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                    }
                    .padding(4)
                    .foregroundStyle(.primary)
                    
                }
                Spacer()
                if showLookAroundScene {
                    Button("Directions", systemImage: "map.fill") {
                        showLookAroundScene.toggle()
                    }
                    .padding(4)
                    .foregroundStyle(.primary)
                } else {
                    Button("Look Around", systemImage: "binoculars.fill") {
                        showLookAroundScene.toggle()
                    }
                    .padding(4)
                    .foregroundStyle(.primary)
                }
                Spacer()
            }
        }
#else
        HStack {
            if !showLookAroundScene {
                Spacer()
                Picker("Route Start Location", selection:$model.rawLocationIdent) {
                    ForEach(chatModel.filteredLocationResults, id:\.self) { result in
                        Text(result.locationName).tag(result.id.uuidString)
                    }
                }.foregroundStyle(.primary)
                Spacer()
                Picker("Transport Type", selection: $model.rawTransportType) {
                    Text(RawTransportType.Walking.rawValue).tag(0)
                    Text(RawTransportType.Automobile.rawValue).tag(2)
                }.foregroundStyle(.primary)
                Spacer()
            }
            Spacer()
            if let source = model.source, let destination = model.destination {
                let launchOptions = model.appleMapsLaunchOptions()
                Button("Apple Maps", systemImage: "apple.logo") {
                    MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                }
                .padding(4)
                .foregroundStyle(.primary)
                
            }
            Spacer()
            if showLookAroundScene {
                Button("Directions", systemImage: "map.fill") {
                    showLookAroundScene.toggle()
                }
                .padding(4)
                .foregroundStyle(.primary)
            } else {
                Button("Look Around", systemImage: "binoculars.fill") {
                    showLookAroundScene.toggle()
                }
                .padding(4)
                .foregroundStyle(.primary)
            }
            Spacer()
        }
#endif
    }
}

#Preview {
    let model = PlaceDirectionsViewModel()
    let locationProvider = LocationProvider()
    
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    return PlaceDirectionsControlsView(chatModel: chatModel, model: model, showLookAroundScene: .constant(false))
}
