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
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @ObservedObject public var model:PlaceDirectionsViewModel
    
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
        if let resultId = modelController.selectedPlaceChatResult, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse {
            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
            let title = placeResponse.name
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment:.leading) {
                        if model.showLookAroundScene, let lookAroundScene = model.lookAroundScene {
                            HStack {
                                Spacer()
                                Button("Directions", systemImage: "map.fill") {
                                    model.showLookAroundScene.toggle()
                                }
                                .padding()
                                #if !os(visionOS)
                                .glassEffect()
                                #endif
                            }
                            LookAroundPreview(initialScene: lookAroundScene)
                                .frame(width:geo.size.width - 32, height:geo.size.height - 64)
                                .padding(16)
                                .cornerRadius(16)
                        } else {
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
                            .padding(16)
                        }
                        if let source = model.source, let destination = model.destination {
                            let launchOptions = model.appleMapsLaunchOptions()
                            HStack(alignment: .center) {
                                if model.lookAroundScene != nil {
                                    Button("Look Around", systemImage: "binoculars.fill") {
                                        model.showLookAroundScene.toggle()
                                    }
                                    .padding()
                                    #if !os(visionOS)
                                    .glassEffect()
                                    #endif
                                    .padding()
                                }
                                
                                Button("Open Apple Maps", systemImage: "apple.logo") {
                                    MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                                }
                                .padding()
                                #if !os(visionOS)
                                .glassEffect()
                                #endif
                                .padding()
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
            .task {
                guard let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let latitude = result.placeResponse?.latitude, let longitude = result.placeResponse?.longitude else {
                    return
                }
                
                let destination = CLLocation(latitude:latitude, longitude: longitude)
                var minDistance = Double.greatestFiniteMagnitude
                var minLocation = UUID()
                let allLocationResults = modelController.filteredLocationResults(cacheManager: cacheManager)
                for locationResult in allLocationResults {
                    if let location = locationResult.location, location.distance(from:destination) < minDistance {
                        minLocation = locationResult.id
                        minDistance = location.distance(from:destination)
                    }
                }
                
                model.rawLocationIdent = minLocation.uuidString
                
                guard let sourceLocation = allLocationResults.first(where: { $0.id == minLocation})?.location else {
                    return
                }
                
                do {
                    try await model.refreshDirections(with: sourceLocation, destination:CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                }
            }
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
                    guard let sourceLocation = model.source?.placemark.location, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse else {
                        return
                    }
                    
                    Task{
                        do {
                            try await model.refreshDirections(with: sourceLocation, destination:CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                        } catch {
                            print(error)
                            modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                        }
                    }
                }
        }
        else {
            ContentUnavailableView("No route available", systemImage: "x.circle.fill")
        }
    }
}
