//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @Binding public var columnVisibility:NavigationSplitViewVisibility
    @State private var searchIsPresented = false
    @EnvironmentObject public var cloudCache:CloudCache
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
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
            }
            .listStyle(.sidebar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Current Location", systemImage:"location") {
                    Task {
                        do {
                            if let currentLocationName = try await chatModel.currentLocationName() {
                                try await chatModel.didSearch(caption:currentLocationName, selectedDestinationChatResultID:nil, intent:.Location)
                            } else {
                                showPopover.toggle()
                            }
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }.labelStyle(.iconOnly)
                Button("Add Location", systemImage:"plus") {
                    chatModel.locationSearchText.removeAll()
                    showPopover.toggle()
                }.labelStyle(.iconOnly)
                    .alert("Location Search", isPresented: $showPopover) {
                        VStack {
                            TextField("New York, NY", text: $searchText)
                                .padding()
                            Button(action:{
                                if !searchText.isEmpty {
                                    Task {
                                        do {
                                            try await chatModel.didSearch(caption:searchText, selectedDestinationChatResultID:nil, intent:.Location)
                                            if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                                               let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                                            {
                                                
                                                Task(priority: .userInitiated) {
                                                    if let location = parent.location {
                                                        var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list: nil)
                                                        let record = try await cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                                        userRecord.setRecordId(to:record)
                                                        chatModel.appendCachedLocation(with: userRecord)
                                                        chatModel.refreshCachedResults()
                                                    }
                                                }
                                            }
                                        } catch {
                                            chatModel.analytics?.track(name: "error \(error)")
                                            print(error)
                                        }
                                    }
                                }
                            }, label:{
                                Text("Search")
                            })
                        }
                    }
                
                if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                   let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                {
                    
                    let isSaved = chatModel.cachedLocation(contains:parent.locationName)
                    if isSaved {
                        Button("Remove Location", systemImage:"minus") {
                            if let cachedLocationResults = chatModel.cachedLocationResults(for: "Location", identity:parent.locationName) {
                                Task {
                                    for cachedLocationResult in cachedLocationResults {
                                        
                                        try await cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                    }
                                    chatModel.refreshCachedResults()
                                    
                                }
                            }
                        }.labelStyle(.iconOnly)
                    }
                }
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
    
    return NavigationLocationView(columnVisibility: .constant(NavigationSplitViewVisibility.all), chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
