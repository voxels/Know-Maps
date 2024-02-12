//
//  PlaceView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/18/23.
//

import SwiftUI
import MapKit

struct PlaceView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @ObservedObject public var placeDirectionsViewModel:PlaceDirectionsViewModel
    @Binding public var resultId:ChatResult.ID?
    @State private var sectionSelection = 0
    
    var body: some View {
        if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId) {
            VStack {
                Picker("", selection: $sectionSelection) {
                    Text("About").tag(0)
                    Text("Directions").tag(1)
                    if let detailsResponses = placeChatResult.placeDetailsResponse, let photoResponses = detailsResponses.photoResponses, photoResponses.count > 0 {
                        Text("Photos").tag(2)
                    }
                    if let detailsResponses = placeChatResult.placeDetailsResponse, let tipsResponses = detailsResponses.tipsResponses, tipsResponses.count > 0 {
                        Text("Tips").tag(3)
                    }
                }
                .padding(24)
                .pickerStyle(.segmented)
                Spacer()
                switch sectionSelection {
                case 0:
                    PlaceAboutView(chatHost:chatHost,chatModel: chatModel, locationProvider: locationProvider, resultId: $resultId, sectionSelection: $sectionSelection)
                            .tabItem {
                                Label("About", systemImage: "target")
                            }
                            .tag("About")
                            .onAppear(perform: {
                                chatModel.analytics?.screen(title: "PlaceAboutView")
                            })
                        .compositingGroup()
                case 1:
                    PlaceDirectionsView(chatHost:chatHost, chatModel: chatModel, locationProvider: locationProvider, model: placeDirectionsViewModel, resultId: $resultId)
                            .tabItem {
                                Label("Directions", systemImage: "map")
                            }
                            .tag("Directions")
                            .onAppear(perform: {
                                chatModel.analytics?.screen(title: "PlaceDirectionsView")
                            })
                        .compositingGroup()
                case 2:
                    if let detailsResponses = placeChatResult.placeDetailsResponse {
                        if let photoResponses = detailsResponses.photoResponses, photoResponses.count > 0 {
                            PlacePhotosView(chatHost:chatHost,chatModel: chatModel, locationProvider: locationProvider, resultId: $resultId)
                                .tabItem {
                                    Label("Photos", systemImage: "photo.stack")
                                }
                                .tag("Photos")
                                .onAppear(perform: {
                                    chatModel.analytics?.screen(title: "PlacePhotosView")
                                })
                                .compositingGroup()
                        }
                    }
                case 3:
                    if let detailsResponses = placeChatResult.placeDetailsResponse {
                        if let tipsResponses = detailsResponses.tipsResponses, tipsResponses.count > 0 {
                            PlaceTipsView(chatHost:chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $resultId)
                                .tabItem {
                                    Label("Tips", systemImage: "quote.bubble")
                                }
                                .tag("Tips")
                                .onAppear(perform: {
                                    chatModel.analytics?.screen(title: "PlaceTipsView")
                                })
                                .compositingGroup()
                        }
                    }
                default:
                    ContentUnavailableView("No Place Selected", systemImage:"return")
                }
            }
        } else {
            ContentUnavailableView("No place selected", systemImage: "return")
                .onAppear(perform: {
                    chatModel.resetPlaceModel()
            })
        }
    }
}

#Preview {

    let locationProvider = LocationProvider()

    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)

    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    let placeDirectionViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    return PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionViewModel, resultId: .constant(nil))
}
