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
    static let mapFrameConstraint:Double = 200000

    var body: some View {
        if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let currentLocation = locationProvider.lastKnownLocation, let placeResponse = result.placeResponse {
            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
            let maxDistance = currentLocation.distance(from: placeCoordinate) + PlaceDirectionsView.mapFrameConstraint
            let title = placeResponse.name
            Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: currentLocation.distance(from: placeCoordinate) + 500, maximumDistance:maxDistance)) {
                Marker(title, coordinate: placeCoordinate.coordinate)
                if currentLocation.distance(from: placeCoordinate) < PlaceDirectionsView.mapFrameConstraint {
                    Marker("Current Location", coordinate: currentLocation.coordinate)
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
