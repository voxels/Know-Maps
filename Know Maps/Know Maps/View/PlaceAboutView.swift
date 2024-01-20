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
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @Binding public var sectionSelection:Int
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
                                    Capsule().frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                    #if os(macOS)
                                        .foregroundStyle(.background)
                                    #else
                                        .foregroundColor(Color(uiColor:.systemFill))
                                    #endif
                                        
                                    Label(placeResponse.formattedAddress, systemImage: "mappin").foregroundStyle(.primary)
                                    
                                }
                                .padding(PlaceAboutView.defaultPadding)
                                .onTapGesture {
                                    sectionSelection = 1
                                }
                                
                                HStack {
                                    ZStack {
                                        Capsule().frame(height: PlaceAboutView.buttonHeight, alignment: .center)                                    
#if os(macOS)
                                            .foregroundStyle(.background)
                                        #else
                                            .foregroundColor(Color(uiColor:.systemFill))
                                        #endif

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
                                            Capsule()
#if os(macOS)
    .foregroundStyle(.background)
#else
    .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            if sizeClass == .compact {
                                                Label("\(tel)", systemImage: "phone")
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(.primary)
                                                    .labelStyle( .iconOnly )
                                            } else {
                                                Label("\(tel)", systemImage: "phone")
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(.primary)
                                                    .labelStyle( .titleOnly)
                                            }
                                        }.onTapGesture {
#if os(visionOS) || os(iOS)
                                            if let url = URL(string: "tel://\(tel)") {
                                                openURL(url)
                                            }
#endif
                                        }
                                    }
                                    
                                    
                                    
                                    if let website = placeDetailsResponse.website, let url = URL(string: website) {
                                        ZStack {
                                            Capsule()
                                                .onTapGesture {
                                                    openURL(url)
                                                }
#if os(macOS)
    .foregroundStyle(.background)
#else
    .foregroundColor(Color(uiColor:.systemFill))
#endif
                                            Link(destination: url) {
                                                Label("Visit website", systemImage: "link")
                                                    .foregroundStyle(.primary)
#if os(iOS) || os(visionOS)
                                                    .labelStyle(.iconOnly)
                                                    .tint(Color.primary)
#endif
                                            }.foregroundColor(Color.primary)
                                        }
                                    }
                                    
                                    if let price = placeDetailsResponse.price {
                                        ZStack {
                                            Capsule()
#if os(macOS)
    .foregroundStyle(.background)
#else
    .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(width: PlaceAboutView.buttonHeight, height: PlaceAboutView.buttonHeight, alignment: .center)
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
                                            Capsule()
#if os(macOS)
    .foregroundStyle(.background)
#else
    .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            Label(PlacesList.formatter.string(from: NSNumber(value: rating)) ?? "0", systemImage: "quote.bubble").foregroundStyle(.primary)
#if os(iOS)
                                                .labelStyle(.titleOnly)
#endif
                                            
                                        }.onTapGesture {
                                            sectionSelection = 3
                                        }
                                    }
                                    
#if os(iOS) || os(visionOS)
                                    ZStack {
                                        Capsule()
                                            .foregroundColor(Color(uiColor:.systemFill))

                                        Image(systemName: "square.and.arrow.up").foregroundStyle(.primary)
                                    }
                                    .onTapGesture {
                                        self.isPresentingShareSheet.toggle()
                                    }
#endif
                                    
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
                        ZStack(alignment: .center) {
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
    
    return PlaceAboutView(chatHost:chatHost,chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil), sectionSelection:.constant(0))
}
