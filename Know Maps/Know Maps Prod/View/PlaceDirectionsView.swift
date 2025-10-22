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
                            LookAroundPreview(initialScene: lookAroundScene)
                                .padding(16)
                                .frame(width:geo.size.width, height:geo.size.height)
                                .cornerRadius(32)
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
                .toolbar {
                    ToolbarItemGroup {
                        
                        if let source = model.source, let destination = model.destination {
                            let launchOptions = model.appleMapsLaunchOptions()
                            Button("Maps", systemImage: "map") {
                                MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                            }
                            
                            if model.lookAroundScene != nil && !model.showLookAroundScene {
                                Button("Look Around", systemImage: "binoculars") {
                                    model.showLookAroundScene.toggle()
                                }
                            } else if model.lookAroundScene != nil && model.showLookAroundScene {
                                Button("Directions", systemImage:"list.number") {
                                    model.showLookAroundScene.toggle()
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: model.rawLocationIdent, { oldValue, newValue in
                if let newValue  {
                    let ident = newValue
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
                var minLocation = ""
                let allLocationResults = modelController.filteredLocationResults()
                for locationResult in allLocationResults {
                    let location = locationResult.location 
                    if location.distance(from:destination) < minDistance {
                        minLocation = locationResult.id
                        minDistance = location.distance(from:destination)
                    }
                }
                
                model.rawLocationIdent = minLocation
                
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
