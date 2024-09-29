//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @State private var searchIsPresented = false
    @EnvironmentObject public var cloudCache:CloudCache
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var searchText:String = ""
    
    @State private var showPopover:Bool = false
    
    var body: some View {
        GeometryReader { geo in
            Section {
                List(chatModel.filteredLocationResults, selection:$chatModel.selectedDestinationLocationChatResult) { result in
                    let isSaved = chatModel.cachedLocation(contains:result.locationName)
                    HStack {
                        if result.id == chatModel.selectedDestinationLocationChatResult {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.red)
                        } else {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.blue)
                        }
                        Spacer()
                        isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                    }
                }
                .listStyle(.automatic)
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags:featureFlags)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
}
