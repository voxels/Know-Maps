//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @State private var searchText: String = ""

    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @State private var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject private var chatModel =  ChatResultViewModel()
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        NavigationSplitView {
            SearchView(chatHost: chatHost, model: chatModel).searchable(text: $searchText) // Adds a search field.
        } content: {
            PlacesList()
        } detail: {
            MapResultsView()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
