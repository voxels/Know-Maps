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
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @State private var route:MKRoute?
    @State private var source:MKMapItem?
    @State private var destination:MKMapItem?
    @State private var polyline:MKPolyline?
    @State private var transportType:MKDirectionsTransportType?
    static let mapFrameConstraint:Double = 200000
    static let mapFrameMinimumPadding:Double = 1000
    static let polylineStrokeWidth:CGFloat = 16
    

    var body: some View {
        if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let currentLocation = locationProvider.lastKnownLocation, let placeResponse = result.placeResponse {
            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
            let maxDistance = currentLocation.distance(from: placeCoordinate) + PlaceDirectionsView.mapFrameConstraint
            let title = placeResponse.name
            Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: currentLocation.distance(from: placeCoordinate) + PlaceDirectionsView.mapFrameMinimumPadding, maximumDistance:maxDistance)) {
                Marker(title, coordinate: placeCoordinate.coordinate)
                if currentLocation.distance(from: placeCoordinate) < PlaceDirectionsView.mapFrameConstraint {
                    Marker("Current Location", coordinate: currentLocation.coordinate)
                }
                
                if let polyline = polyline {
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
            .padding()
            .onChange(of: resultId) { oldValue, newValue in
                guard let placeChatResult = chatModel.placeChatResult(for: newValue), let placeResponse = placeChatResult.placeResponse else {
                    return
                }
                
                if oldValue != newValue, let sourceMapItem = mapItem(for: locationProvider.lastKnownLocation), let destinationMapItem = mapItem(for: CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)) {
                    getDirections(source:sourceMapItem, destination:destinationMapItem)
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
    
    func getDirections(source:MKMapItem?, destination:MKMapItem?) {
        guard let source = source, let destination = destination else {
            return
        }
        route = nil
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        
        Task {
            let directions = MKDirections(request: request)
            let response = try? await directions.calculate()
            await MainActor.run {
                self.route = response?.routes.first
                self.source = source
                self.polyline = self.route?.polyline
            }
        }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model

    return PlaceDirectionsView(chatHost: chatHost, chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))
}
