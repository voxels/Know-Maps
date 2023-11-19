//
//  PlaceView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/18/23.
//

import SwiftUI
import MapKit

struct PlaceView: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var model:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @State private var position: Int?
    var body: some View {
        if let resultId = resultId, let selectedPlaceResult = model.placeChatResult(for: resultId){
            VStack {
                if let placeResponse = selectedPlaceResult.placeResponse {
                    let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                    let currentLocation = locationProvider.lastKnownLocation
                    let maxDistance = (currentLocation?.distance(from: placeCoordinate) ?? 4500) + 10000
                    Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: maxDistance - 10000, maximumDistance:maxDistance)) {
                            Marker(selectedPlaceResult.title, coordinate: placeCoordinate.coordinate)
                            if let currentLocation = currentLocation {
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
                        
                    if let detailsResponse = selectedPlaceResult.placeDetailsResponse {
                        Spacer()
                        VStack(alignment: .leading) {
                            if let photoResponses = detailsResponse.photoResponses {
                                ScrollView(.horizontal) {
                                    LazyHStack {
                                        ForEach(photoResponses) { response in
                                            if let url = response.photoUrl() {
                                                AsyncImage(url: url) { image in
                                                    image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(maxWidth: 900, maxHeight: 900)
                                                } placeholder: {
                                                    Rectangle()
                                                        .foregroundColor(.gray)
                                                        .frame(width: 300, height:300)
                                                }

                                            }
                                        }
                                    }
                                    .scrollTargetLayout()
                                }.scrollPosition(id: $position)
                                .onChange(of: resultId) { oldValue, newValue in
                                    position = 0
                                }
                            }
                            Spacer()
                            ZStack {
                                Rectangle().foregroundStyle(.thickMaterial)
                                VStack(alignment:.leading){
                                    Text(placeResponse.name).bold()
                                    Text(placeResponse.categories.joined(separator: ", ")).italic()
                                    Text(placeResponse.formattedAddress)
                                    if let tel = detailsResponse.tel {
                                        Text(tel)
                                    }
                                    if let website = detailsResponse.website {
                                        Text(website)
                                    }
                                }
                            }

                        }
                    } else {
                        VStack {
                            Text(placeResponse.name)
                            Text(placeResponse.categories.joined(separator: ", "))
                            Text(placeResponse.formattedAddress)
                        }
                    }
                } else {
                    Text("No place details")
                }
            }
        } else {
          Text("No place selected")
        }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model
    return PlaceView(chatHost: chatHost, model: model, locationProvider: locationProvider, resultId: .constant(nil))
}
