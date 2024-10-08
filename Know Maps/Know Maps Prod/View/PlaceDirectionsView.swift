//
//  PlaceDirectionsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import CoreLocation
import MapKit
import Segment

struct PlaceDirectionsView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var model:PlaceDirectionsViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject var modelController:DefaultModelController
    @Binding public var resultId:ChatResult.ID?
        
    static let mapFrameConstraint:Double = 200000
    static let mapFrameMinimumPadding:Double = 1000
    static let polylineStrokeWidth:CGFloat = 8
    
    private var travelTime: String? {
        guard let route = model.route else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: route.expectedTravelTime)
    }

    var body: some View {
        if let resultId = resultId, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse {
            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
            let title = placeResponse.name
            GeometryReader { geo in
                
                ScrollView {
                    VStack(alignment: .center) {
                        
                        if model.showLookAroundScene, let lookAroundScene = model.lookAroundScene {
                                LookAroundPreview(initialScene: lookAroundScene)
                                    .overlay {
                                        if let source = model.source, let destination = model.destination {
                                            let launchOptions = model.appleMapsLaunchOptions()
                                            VStack(alignment: .center) {
                                                HStack {
                                                    Button("Directions", systemImage: "map.fill") {
                                                        model.showLookAroundScene.toggle()
                                                    }
                                                    .padding(.horizontal, 24)
                                                    .padding(.vertical, 64)
                                                    .foregroundStyle(.primary)
                                                    .background()
                                                    Spacer()
                                                }
                                                Spacer()
                                                Button("Open Apple Maps", systemImage: "apple.logo") {
                                                    MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                                                }
                                                .padding(8)
                                                .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    .onChange(of: model.destination) {
                                        if let destination = model.destination {
                                            Task {
                                                do {
                                                    try await model.getLookAroundScene(mapItem:destination)
                                                } catch {
                                                    modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                                                }
                                            }
                                        }
                                    }
                                    .frame(minWidth: geo.size.width, minHeight:geo.size.height * 2.0 / 3.0)
                            } else {
                                HStack {
                                    Text("Route start:")
                                    Picker("", selection:$model.rawLocationIdent) {
                                        ForEach(modelController.filteredLocationResults(cacheManager: cacheManager), id:\.self) { result in
                                            Text(result.locationName).tag(result.id.uuidString)
                                        }
                                    }.foregroundStyle(.primary)
                                        .pickerStyle(.menu)
                                }.padding(.horizontal, 16)
                                Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 1500, maximumDistance:250000)) {
                                    Marker(title, coordinate: placeCoordinate.coordinate)
                                    
                                    if let polyline = model.polyline {
                                        MapPolyline(polyline)
                                            .stroke(.blue, lineWidth: PlaceDirectionsView.polylineStrokeWidth)
                                    }
                                }
                                .mapControls {
                                    MapPitchToggle()
                                    MapUserLocationButton()
                                    MapCompass()
                                }
                                .mapStyle(.standard)
                                .frame(minWidth: geo.size.width-48, minHeight:geo.size.height * 2.0 / 3.0)
                                .cornerRadius(16)
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                                .overlay {
                                    if let source = model.source, let destination = model.destination {
                                        let launchOptions = model.appleMapsLaunchOptions()
                                        VStack(alignment: .center) {
                                            if model.lookAroundScene != nil {
                                                HStack {
                                                    Button("Look Around", systemImage: "binoculars.fill") {
                                                        model.showLookAroundScene.toggle()
                                                    }
                                                    .padding(36)
                                                    .foregroundStyle(.primary)
                                                    Spacer()
                                                }
                                            }
                                            Spacer()
                                            Button("Open Apple Maps", systemImage: "apple.logo") {
                                                MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                                            }
                                            .padding(8)
                                            .foregroundStyle(.primary)
                                        }
                                    }
                                    
                                }
                            }
                        if !model.showLookAroundScene {
                                Picker("Transport Type", selection: $model.rawTransportType) {
                                    Text(PlaceDirectionsViewModel.RawTransportType.Automobile.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Automobile)
                                    Text(PlaceDirectionsViewModel.RawTransportType.Walking.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Walking)
                                }.foregroundStyle(.primary)
                                    .pickerStyle(.palette)
                                    .padding(.horizontal, 16)
                            }
                        if let chatRouteResults = model.chatRouteResults, chatRouteResults.count > 0  {
                            VStack(alignment: .leading) {
                                ForEach(chatRouteResults) { chatRouteResult in
                                    Text(chatRouteResult.instructions)
                                }
                            }.padding(16)
                         
                        }
                    }
                }
            }
            .onChange(of: model.rawLocationIdent, { oldValue, newValue in
                if let ident = UUID(uuidString: newValue) {
                    guard let sourceLocation = modelController.locationChatResult(for: ident, in:modelController.locationResults)?.location, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse else {
                        return
                    }
                    
                    Task{
                        do {
                            try await model.refreshDirections(with: sourceLocation, destination:CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                        }
                    }
                }
            })
            .onChange(of: model.rawTransportType) { oldValue, newValue in
                switch newValue {
                case .Walking:
                    model.transportType = .walking
                case .Transit:
                    model.transportType = .transit
                case .Automobile:
                    model.transportType = .automobile
                }
            }
            .onChange(of: model.transportType) { oldValue, newValue in
                if let ident = UUID(uuidString: model.rawLocationIdent) {
                    guard let sourceLocation = modelController.locationChatResult(for: ident, in:modelController.locationResults)?.location, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse else {
                        return
                    }
                    
                    Task{
                        do {
                            try await model.refreshDirections(with: sourceLocation, destination:CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                        }
                    }
                }
            }
        }
        else {
            ContentUnavailableView("No route available", systemImage: "x.circle.fill")
        }
    }
}
