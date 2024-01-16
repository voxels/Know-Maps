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
                if let source = model.source, let destination = model.destination {
                    let launchOptions = model.appleMapsLaunchOptions()
                    ZStack {
                        Capsule().foregroundColor(Color(uiColor:.systemFill))
                        Button {
                            MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                        } label: {
                            Label("Apple Maps", systemImage: "apple.logo")
                                .foregroundStyle(.primary)
                        }.foregroundStyle(.primary)
                        .padding(4)
                    }
                }
                if showLookAroundScene {
                    ZStack {
                        Capsule().foregroundColor(Color(uiColor:.systemFill))
                        Button("Directions", systemImage: "map.fill") {
                            showLookAroundScene.toggle()
                        }
                        .padding(4)
                        .foregroundStyle(.primary)
                    }
                } else {
                    ZStack {
                        Capsule().foregroundColor(Color(uiColor:.systemFill))
                        Button("Look Around", systemImage: "binoculars.fill") {
                            showLookAroundScene.toggle()
                        }
                        .padding(4)
                        .foregroundStyle(.primary)
                    }
                }
            }
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
