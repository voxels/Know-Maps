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
    
    var body: some View {
        TabView {
            PlaceAboutView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("About", systemImage: "target")
                }
            PlacePhotosView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("Photos", systemImage: "photo.stack")
                }
            PlaceReviewsView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("Reviews", systemImage: "quote.bubble")
                }
            PlaceDirectionsView(chatHost:chatHost,chatModel: model, locationProvider: locationProvider, resultId: $resultId)
                .tabItem {
                    Label("Directions", systemImage: "map")
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
    return PlaceView(chatHost: chatHost, model: model, locationProvider: locationProvider, resultId: .constant(nil))
}
