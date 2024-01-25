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
    @Binding public var lookAroundScene:MKLookAroundScene?
    
    var body: some View {
#if os(iOS)
        VStack {
            HStack {
                if !showLookAroundScene {
                    Picker("Route Start Location", selection:$model.rawLocationIdent) {
                        ForEach(chatModel.filteredLocationResults, id:\.self) { result in
                            Text(result.locationName).tag(result.id.uuidString)
                        }
                    }.foregroundStyle(.primary)
                    Spacer()
                    Picker("Transport Type", selection: $model.rawTransportType) {
                        Text(PlaceDirectionsViewModel.RawTransportType.Automobile.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Automobile)
                        Text(PlaceDirectionsViewModel.RawTransportType.Walking.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Walking)
                    }.foregroundStyle(.primary)
                }
            }
            HStack {
                if showLookAroundScene {
                    Button("Directions", systemImage: "map.fill") {
                        showLookAroundScene.toggle()
                    }
                    .padding(8)
                    .foregroundStyle(.primary)
                } else if lookAroundScene != nil {
                    Button("Look Around", systemImage: "binoculars.fill") {
                        showLookAroundScene.toggle()
                    }
                    .padding(8)
                    .foregroundStyle(.primary)
                }
                Spacer()
                if let source = model.source, let destination = model.destination {
                    let launchOptions = model.appleMapsLaunchOptions()
                    Button("Apple Maps", systemImage: "apple.logo") {
                        MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                    }
                    .padding(8)
                    .foregroundStyle(.primary)
                    
                }
            }
        }
#else
        HStack {
            if !showLookAroundScene {
                Picker("Route Start Location", selection:$model.rawLocationIdent) {
                    ForEach(chatModel.filteredLocationResults, id:\.self) { result in
                        Text(result.locationName).tag(result.id.uuidString)
                    }
                }.foregroundStyle(.primary)
                Picker("Transport Type", selection: $model.rawTransportType) {
                    Text(PlaceDirectionsViewModel.RawTransportType.Automobile.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Automobile)
                    Text(PlaceDirectionsViewModel.RawTransportType.Walking.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Walking)
                }.foregroundStyle(.primary)
            }
            Spacer()
#if os(iOS) || os(visionOS)
            if showLookAroundScene {
                Button("Directions", systemImage: "map.fill") {
                    showLookAroundScene.toggle()
                }
                .padding(4)
                .foregroundStyle(.primary)
            } else if lookAroundScene != nil{
                Button("Look Around", systemImage: "binoculars.fill") {
                    showLookAroundScene.toggle()
                }
                .padding(4)
                .foregroundStyle(.primary)
            }
            #endif
            if let source = model.source, let destination = model.destination {
                let launchOptions = model.appleMapsLaunchOptions()
                Button("Apple Maps", systemImage: "apple.logo") {
                    MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                }
                .padding(4)
                .foregroundStyle(.primary)
            }
        }
#endif
    }
}

#Preview {
    let model = PlaceDirectionsViewModel( rawLocationIdent: "")
    let locationProvider = LocationProvider()
    
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags(cloudCache: cloudCache)

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    return PlaceDirectionsControlsView(chatModel: chatModel, model: model, showLookAroundScene: .constant(false), lookAroundScene: .constant(nil))
}
