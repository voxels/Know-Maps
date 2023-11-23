//
//  PlaceDirectionsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct PlaceDirectionsView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @ObservedObject public var model:PlaceDirectionsViewModel
    @Binding public var resultId:ChatResult.ID?
    
    static let mapFrameConstraint:Double = 200000
    static let mapFrameMinimumPadding:Double = 1000
    static let polylineStrokeWidth:CGFloat = 16
    
    public enum RawTransportType : String {
        case Walking
        case Transit
        case Automobile
    }
    

    var body: some View {
        if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let currentLocation = locationProvider.lastKnownLocation, let placeResponse = result.placeResponse {
            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
            let maxDistance = currentLocation.distance(from: placeCoordinate) + PlaceDirectionsView.mapFrameConstraint
            let title = placeResponse.name
            GeometryReader { geo in
                LazyVStack(alignment: .leading) {
                    HStack {
                        Spacer()
                        Picker("Transport Type", selection: $model.rawTransportType) {
                            Text(RawTransportType.Walking.rawValue).tag(0)
                            Text(RawTransportType.Transit.rawValue).tag(1)
                            Text(RawTransportType.Automobile.rawValue).tag(2)
                        }
                        Spacer()
                    }
                    Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: currentLocation.distance(from: placeCoordinate) + PlaceDirectionsView.mapFrameMinimumPadding, maximumDistance:maxDistance)) {
                        Marker(title, coordinate: placeCoordinate.coordinate)
                        if currentLocation.distance(from: placeCoordinate) < PlaceDirectionsView.mapFrameConstraint {
                            Marker("Current Location", coordinate: currentLocation.coordinate)
                        }
                        
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
                    .mapStyle(.hybrid(elevation: .realistic,
                                      pointsOfInterest: .including([.publicTransport]),
                                      showsTraffic: true))
                    .frame(minWidth: geo.size.width, minHeight:geo.size.height * 2.0 / 3.0)
                    .padding()
                    
                    if let chatRouteResults = model.chatRouteResults, chatRouteResults.count > 0  {
                        ForEach(chatRouteResults) { chatRouteResult in
                            Label(chatRouteResult.instructions, systemImage: "arrowtriangle.right.fill").frame(alignment: .leading)
                        }
                    }
                }
            }
            .onChange(of: resultId) { oldValue, newValue in
                guard let placeChatResult = chatModel.placeChatResult(for: newValue), let placeResponse = placeChatResult.placeResponse else {
                    return
                }
                
                if oldValue != newValue, let sourceMapItem = mapItem(for: locationProvider.lastKnownLocation), let destinationMapItem = mapItem(for: CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)) {
                    Task { @MainActor in
                        do {
                            try await getDirections(source:sourceMapItem, destination:destinationMapItem, model:model)
                            self.resultId = resultId
                        } catch {
                            print(error)
                        }
                        
                    }
                }
            }
            .onChange(of: model.rawTransportType) { oldValue, newValue in
                switch newValue {
                case 0:
                    model.transportType = .walking
                case 1:
                    model.transportType = .transit
                case 2:
                    model.transportType = .automobile
                default:
                    model.transportType = .any
                }
            }
            .onChange(of: model.transportType) { oldValue, newValue in
                guard let placeChatResult = chatModel.placeChatResult(for: resultId), let placeResponse = placeChatResult.placeResponse else {
                    return
                }
                
                if let sourceMapItem = mapItem(for: locationProvider.lastKnownLocation), let destinationMapItem = mapItem(for: CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)) {
                    Task { @MainActor in
                        do {
                            try await getDirections(source:sourceMapItem, destination:destinationMapItem, model:model)
                            self.resultId = resultId
                        } catch {
                            print(error)
                        }
                        
                    }
                }
            }
        }
        else {
            ContentUnavailableView("No route available", image: "x.circle.fill")
        }
    }
    
    func mapItem(for location:CLLocation?)->MKMapItem? {
        guard let location = location, let placemark = placemark(for: location) else {
            return nil
        }
        return MKMapItem(placemark: placemark)
    }
    
    func placemark(for location:CLLocation?)->MKPlacemark? {
        guard let location = location else {
            return nil
        }
        return MKPlacemark(coordinate: location.coordinate)
    }
    
    @MainActor
    func getDirections(source:MKMapItem?, destination:MKMapItem?, model:PlaceDirectionsViewModel) async throws{
        guard let source = source, let destination = destination else {
            return
        }
                
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = model.transportType
        
        let directions = MKDirections(request: request)
                                    
        let response = try? await directions.calculate()
        model.source = source
        model.route = response?.routes.first
        if let route = model.route {
            model.polyline = route.polyline
            model.chatRouteResults = route.steps.compactMap({ step in
                let instructions = step.instructions
                if !instructions.isEmpty {
                    return ChatRouteResult(route: route, instructions: instructions)
                }
                return nil
            })
        }
        
        return
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    let model = PlaceDirectionsViewModel()

    return PlaceDirectionsView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, model: model, resultId: .constant(nil))
}
