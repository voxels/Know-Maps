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
    
    @State private var selectedTab = "About"
    
    var body: some View {
        if let resultId = resultId, let placeChatResult = model.placeChatResult(for: resultId) {
        TabView(selection: $selectedTab) {
                PlaceAboutView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId, selectedTab: $selectedTab)
                    .tabItem {
                        Label("About", systemImage: "target")
                    }
                    .tag("About")
                PlaceDirectionsView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                    .tabItem {
                        Label("Directions", systemImage: "map")
                    }
                    .tag("Directions")
                
                if let detailsResponses = placeChatResult.placeDetailsResponse {
                    if let photoResponses = detailsResponses.photoResponses, photoResponses.count > 0 {
                        PlacePhotosView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                            .tabItem {
                                Label("Photos", systemImage: "photo.stack")
                            }
                            .tag("Photos")
                    }
                    if let tipsResponses = detailsResponses.tipsResponses, tipsResponses.count > 0 {
                        PlaceReviewsView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                            .tabItem {
                                Label("Tips", systemImage: "quote.bubble")
                            }
                            .tag("Tips")
                    }
                }
            }
        } else {
            ContentUnavailableView("No place selected", systemImage: "return")
        }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model
    return PlaceView(chatHost: chatHost, model: model, locationProvider: locationProvider, resultId: .constant(nil))
}
