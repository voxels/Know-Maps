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
    @State private var presentingPopover:Bool = false
    
#if os(visionOS) || os(iOS)
    @State private var callController = CXCallController()
#endif
    @State private var isPresentingShareSheet:Bool = false
    static let defaultPadding:CGFloat = 8
    static let mapFrameConstraint:Double = 50000
    static let buttonHeight:Double = 44
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                        let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                        
                        let title = placeResponse.name
                        Map(initialPosition: .automatic) {
                            Marker(title, coordinate: placeCoordinate.coordinate)
                        }
                        .mapControls {
                            MapPitchToggle()
                            MapUserLocationButton()
                            MapCompass()
                        }
                        .mapStyle(.hybrid(elevation: .automatic,
                                          pointsOfInterest: .including([.publicTransport]),
                                          showsTraffic: false))
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
                                
                                
                                ZStack {
                                    Capsule().frame(height: PlaceAboutView.buttonHeight, alignment: .center).foregroundColor(Color(uiColor:.systemFill))
                                    Label(placeResponse.formattedAddress, systemImage: "mappin").foregroundStyle(.primary)
                                    
                                }
                                .padding(PlaceAboutView.defaultPadding)
                                .onTapGesture {
                                    selectedTab = "Directions"
                                }
                                
                                HStack {
                                    ZStack {
                                        Capsule().frame(height: PlaceAboutView.buttonHeight, alignment: .center).foregroundColor(Color(uiColor:.systemFill))
                                        Label("Add to List", systemImage: "star")
#if os(iOS) || os(visionOS)
                                            .labelStyle(.iconOnly).foregroundStyle(.primary)
#endif
                                    }.onTapGesture {
                                        presentingPopover.toggle()
                                    }.popover(isPresented: $presentingPopover) {
                                        AddListItemView(chatModel: chatModel, presentingPopover:$presentingPopover)
                                            .frame(width:300, height:600)
                                            .presentationCompactAdaptation(.automatic)
                                    }
                                    
                                    if let tel = placeDetailsResponse.tel {
                                        ZStack {
                                            Capsule().foregroundColor(Color(uiColor:.systemFill)).frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            Label("Call \(tel)", systemImage: "phone").foregroundStyle(.primary)
#if os(iOS) || os(visionOS)
                                                .labelStyle(.iconOnly)
#endif
                                            
                                        }.onTapGesture {
#if os(visionOS) || os(iOS)
                                            call(tel:tel)
#endif
                                        }
                                    }
                                    
                                    
                                    
                                    if let website = placeDetailsResponse.website, let url = URL(string: website) {
                                        ZStack {
                                            Capsule().foregroundColor(Color(uiColor:.systemFill))
                                            Link(destination: url) {
                                                Label("Visit website", systemImage: "link").foregroundStyle(.primary)
#if os(iOS) || os(visionOS)
                                                    .labelStyle(.iconOnly)
#endif
                                            }
                                        }
                                    }
#if os(visionOS) || os(iOS)
                                    
                                    ZStack {
                                        Capsule().foregroundColor(Color(uiColor:.systemFill))
                                        Image(systemName: "square.and.arrow.up").foregroundStyle(.primary)
                                    }
                                    .onTapGesture {
                                        self.isPresentingShareSheet.toggle()
                                    }
#endif
                                    
                                    
                                    if let price = placeDetailsResponse.price {
                                        ZStack {
                                            Capsule().foregroundColor(Color(uiColor:.systemFill)).frame(width: PlaceAboutView.buttonHeight, height: PlaceAboutView.buttonHeight, alignment: .center)
                                            switch price {
                                            case 1:
                                                Text("$").foregroundStyle(.primary)
                                            case 2:
                                                Text("$$").foregroundStyle(.primary)
                                            case 3:
                                                Text("$$$").foregroundStyle(.primary)
                                            case 4:
                                                Text("$$$$").foregroundStyle(.primary)
                                            default:
                                                Text("\(price)").foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    
                                    let rating = placeDetailsResponse.rating
                                    if rating > 0 {
                                        ZStack {
                                            Capsule().foregroundColor(Color(uiColor:.systemFill)).frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            Label(PlacesList.formatter.string(from: NSNumber(value: rating)) ?? "0", systemImage: "quote.bubble").foregroundStyle(.primary)
#if os(iOS)
                                                .labelStyle(.titleOnly)
#endif
                                            
                                        }.onTapGesture {
                                            selectedTab = "Tips"
                                        }
                                    }
                                    Spacer()
                                }.padding(PlaceAboutView.defaultPadding)
                            }
                        }.padding(EdgeInsets(top: 0, leading: PlaceAboutView.defaultPadding * 2, bottom: PlaceAboutView.defaultPadding, trailing: PlaceAboutView.defaultPadding * 2))
                            .popover(isPresented: $isPresentingShareSheet) {
                                if let result = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = result.placeDetailsResponse  {
                                    let items:[Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.address]
#if os(visionOS) || os(iOS)
                                    ActivityViewController(activityItems:items, applicationActivities:[UIActivity](), isPresentingShareSheet: $isPresentingShareSheet)
#endif
                                }
                            }
                    } else {
                        ZStack {
                            ProgressView().progressViewStyle(.circular)
                        }
                    }
                }
            }
        }
    }
    
    
#if os(visionOS) || os(iOS)
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
#endif
}

#Preview {
    
    let locationProvider = LocationProvider()
    
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return PlaceAboutView(chatHost:chatHost,chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil), selectedTab: .constant("About"))
}
