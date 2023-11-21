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
        TabView(selection: $selectedTab) {
            PlaceAboutView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId, selectedTab: $selectedTab)
                .tabItem {
                    Label("About", systemImage: "target")
                }
                .tag("About")
            PlacePhotosView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("Photos", systemImage: "photo.stack")
                }
                .tag("Photos")
            PlaceReviewsView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("Reviews", systemImage: "quote.bubble")
                }
                .tag("Reviews")
            PlaceDirectionsView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("Directions", systemImage: "map")
                }
                .tag("Directions")
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
