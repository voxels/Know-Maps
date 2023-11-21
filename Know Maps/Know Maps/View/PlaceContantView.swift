//
//  PlaceContantView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct PlaceContantView: View {
    
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?

    @State private var position: Int?
    
    static let defaultPadding:CGFloat = 16
    static let mapFrameConstraint:Double = 50000
    static let buttonHeight:Double = 60
    static let maxPhotoDim:CGFloat = 300
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack {
                    if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let currentLocation = locationProvider.lastKnownLocation, let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                        let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                        let maxDistance = currentLocation.distance(from: placeCoordinate) + PlaceContantView.mapFrameConstraint
                        let title = placeResponse.name
                        Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: currentLocation.distance(from: placeCoordinate) + 500, maximumDistance:maxDistance)) {
                            Marker(title, coordinate: placeCoordinate.coordinate)
                            if currentLocation.distance(from: placeCoordinate) < PlaceContantView.mapFrameConstraint {
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
                        .frame(minHeight: geo.size.height / 2.0)
                        HStack(alignment:.top){
                            ZStack(alignment: .leading) {
                                Rectangle().foregroundStyle(.clear)
                                VStack(alignment:.leading){
                                    Text(placeResponse.name).bold()
                                    Text(placeResponse.categories.joined(separator: ", ")).italic()
                                    Text(placeResponse.formattedAddress)
                                    if let tel = placeDetailsResponse.tel {
                                        Text(tel)
                                    }
                                    if let website = placeDetailsResponse.website, let url = URL(string: website) {
                                        Link("Website", destination: url)
                                    }
                                }
                            }

                            if let price = placeDetailsResponse.price {
                                ZStack {
                                    Capsule().frame(width: PlaceContantView.buttonHeight, height: PlaceContantView.buttonHeight, alignment: .center).foregroundColor(Color.accentColor)
                                    switch price {
                                    case 1:
                                        Text("$")
                                    case 2:
                                        Text("$$")
                                    case 3:
                                        Text("$$$")
                                    case 4:
                                        Text("$$$$")
                                    default:
                                        Text("\(price)")
                                            .foregroundColor(Color(uiColor: UIColor.label))
                                    }
                                }
                            }
                            
                            let rating = placeDetailsResponse.rating
                            if rating > 0 {
                                ZStack {
                                    Capsule().frame(width: PlaceContantView.buttonHeight, height: PlaceContantView.buttonHeight, alignment: .center).foregroundColor(Color.accentColor)
                                    Text(PlacesList.formatter.string(from: NSNumber(value: rating)) ?? "0")
                                }
                            }
                        }.padding(PlaceContantView.defaultPadding)
                        ZStack {
                            Rectangle().foregroundStyle(.thickMaterial)
                            VStack(alignment: .leading) {
                                if let photoResponses = placeDetailsResponse.photoResponses {
                                    ScrollView(.horizontal) {
                                        LazyHStack {
                                            ForEach(photoResponses) { response in
                                                if let url = response.photoUrl() {
                                                    AsyncImage(url: url) { image in
                                                        image.resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(maxWidth: PlaceContantView.maxPhotoDim, maxHeight: PlaceContantView.maxPhotoDim)
                                                    } placeholder: {
                                                        Rectangle()
                                                            .foregroundColor(.gray)
                                                            .frame(width: PlaceContantView.maxPhotoDim, height:PlaceContantView.maxPhotoDim)
                                                    }
                                                    
                                                }
                                            }
                                        }
                                        .scrollTargetLayout()
                                    }.scrollPosition(id: $position)
                                        .onChange(of: placeResponse) { oldValue, newValue in
                                            position = 0
                                        }
                                }
                            }
                        }
                        VStack {
                            if let description = placeDetailsResponse.description {
                                Text(description)
                                    .truncationMode(.tail)
                                    .frame(maxHeight:PlaceContantView.maxPhotoDim)
                                    .padding(PlaceContantView.defaultPadding)
                            } else if let tips = placeDetailsResponse.tipsResponses, tips.count > 0  {
                                Button {
                                    Task {
                                        try await chatHost.placeDescription(chatResult: result, delegate: chatModel)
                                    }
                                } label: {
                                    if chatModel.isFetchingPlaceDescription, result.id == chatModel.fetchingPlaceID {
                                        ProgressView().progressViewStyle(.circular)
                                    } else {
                                        Text("Generate GPT-4 Description for \(placeDetailsResponse.searchResponse.name)")
                                    }
                                }.buttonStyle(.bordered)
                                    .padding(PlaceContantView.defaultPadding)
                            } else if let tastes = placeDetailsResponse.tastes, tastes.count > 0 {
                                Button {
                                    Task {
                                        try await chatHost.placeDescription(chatResult: result, delegate: chatModel)
                                    }
                                } label: {
                                    Text("Generate GPT-4 Description for \(placeDetailsResponse.searchResponse.name)")
                                }.buttonStyle(.bordered)
                                    .padding(PlaceContantView.defaultPadding)
                            }
                        }
                    } else {
                        ProgressView().frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    }
                }
            }
        }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model
    
    return PlaceContantView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))
}
