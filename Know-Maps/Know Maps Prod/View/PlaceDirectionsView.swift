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

extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

struct PlaceDirectionsView: View {
    public var chatModel:ChatResultViewModel
    public var cacheManager:CloudCacheManager
    var modelController:DefaultModelController
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
        if let resultId = modelController.selectedPlaceChatResultFsqId,
           let result = modelController.placeChatResult(with: resultId) {
            let title = result.title

            let destinationCoordinate: CLLocationCoordinate2D? = {
                let lat = result.placeResponse?.latitude
                let lon = result.placeResponse?.longitude
                guard let lat, let lon else { return nil }
                if lat == 0, lon == 0 { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }()

            if let destinationCoordinate {
                let placeCoordinate = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment:.leading) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                if let travelTime {
                                    Text(travelTime)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            if model.showLookAroundScene, let lookAroundScene = model.lookAroundScene as? MKLookAroundScene {
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
                                    Text(PlaceDirectionsViewModel.RawTransportType.Transit.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Transit)
                                }.foregroundStyle(.primary)
                                    .pickerStyle(.palette)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
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
                .task { @MainActor in
                    let sourceLocation = modelController.selectedDestinationLocationChatResult.location
                    let destinationLocation = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)

                    do {
                        try await model.refreshDirections(with: sourceLocation, destination: destinationLocation)
                    } catch {
                        modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                    }
                }
                .onChange(of: model.rawTransportType) { newValue in
                    switch newValue {
                    case .Walking:
                        model.transportType = .walking
                    case .Transit:
                        model.transportType = .transit
                    case .Automobile:
                        model.transportType = .automobile
                    }
                }
                .onChange(of: model.transportType) { newValue in
                    guard let sourceLocation = model.source?.placemark.location else {
                        return
                    }
                    
                    Task{ @MainActor in
                        do {
                            try await model.refreshDirections(with: sourceLocation, destination: CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude))
                        } catch {
                            print(error)
                            modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                        }
                    }
                }
            } else {
                ProgressView {
                    Text("Loading location details…")
                }
            }
        } else {
            ContentUnavailableView("No route available", systemImage: "x.circle.fill")
        }
    }
}
