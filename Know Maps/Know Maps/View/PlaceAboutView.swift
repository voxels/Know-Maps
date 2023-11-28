//
//  PlaceContantView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import CoreLocation
import MapKit
import CallKit

struct PlaceAboutView: View {
    
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @Binding public var selectedTab:String

    private let callController = CXCallController()
    
    static let defaultPadding:CGFloat = 8
    static let mapFrameConstraint:Double = 50000
    static let buttonHeight:Double = 44
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack {
                    let currentLocation = locationProvider.lastKnownLocation
                    if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                        let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                        let maxDistance = currentLocation.distance(from: placeCoordinate) + PlaceAboutView.mapFrameConstraint
                        let title = placeResponse.name
                        Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: currentLocation.distance(from: placeCoordinate) + 500, maximumDistance:maxDistance)) {
                            Marker(title, coordinate: placeCoordinate.coordinate)
                            if currentLocation.distance(from: placeCoordinate) < PlaceAboutView.mapFrameConstraint {
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
                        .padding(EdgeInsets(top: 0, leading: PlaceAboutView.defaultPadding * 2, bottom: PlaceAboutView.defaultPadding, trailing: PlaceAboutView.defaultPadding * 2))

                        ZStack(alignment: .leading) {
                            Rectangle().foregroundStyle(.thinMaterial)
                            VStack(){
                                ZStack {
                                    Rectangle().foregroundStyle(.thickMaterial)
                                    VStack{
                                        Text(placeResponse.name).bold()
                                        
                                        Text(placeResponse.categories.joined(separator: ", ")).italic()
                                        
                                    }
                                    .padding(PlaceAboutView.defaultPadding)
                                }
                                .padding(PlaceAboutView.defaultPadding)
                                
                                Button {
                                    selectedTab = "Directions"
                                } label: {
                                    Text(placeResponse.formattedAddress)
                                }
                                .buttonStyle(.bordered)
                                .padding(PlaceAboutView.defaultPadding)
                                
                                HStack {
                                    if let tel = placeDetailsResponse.tel {
                                        Button {
                                            call(tel:tel)
                                        } label: {
                                            Text("Call \(tel)")
                                        }.buttonStyle(.bordered)
                                    }
                                    
                                    
                                    
                                    if let website = placeDetailsResponse.website, let url = URL(string: website) {
                                        ZStack {
                                            Capsule()
                                                .foregroundColor(Color(uiColor:.systemFill))
                                            Link("Visit Website", destination: url).foregroundStyle(.primary)
                                        }
                                    }
                                    
                                    if let price = placeDetailsResponse.price {
                                        ZStack {
                                            Capsule().frame(width: PlaceAboutView.buttonHeight, height: PlaceAboutView.buttonHeight, alignment: .center)
                                                .foregroundColor(Color(uiColor:.systemFill))
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
                                            }
                                        }
                                    }
                                    
                                    let rating = placeDetailsResponse.rating
                                    if rating > 0 {
                                        ZStack {
                                            Capsule().frame(width: PlaceAboutView.buttonHeight, height: PlaceAboutView.buttonHeight, alignment: .center)
                                                .foregroundColor(Color(uiColor:.systemFill))
                                            Text(PlacesList.formatter.string(from: NSNumber(value: rating)) ?? "0")
                                                
                                        }.onTapGesture {
                                            selectedTab = "Tips"
                                        }
                                    }
                                    Spacer()
                                }.padding(PlaceAboutView.defaultPadding)
                            }
                        }.padding(EdgeInsets(top: 0, leading: PlaceAboutView.defaultPadding * 2, bottom: PlaceAboutView.defaultPadding, trailing: PlaceAboutView.defaultPadding * 2))
                    } else {
                        ProgressView().frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    }
                }
            }
        }
    }
    
    func call(tel:String) {
        let uuid = UUID()
        let digits = tel.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: " ", with: "")
        let handle = CXHandle(type: .phoneNumber, value: digits)
         
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
         
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
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
    
    return PlaceAboutView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: .constant(nil), selectedTab: .constant("About"))
}
