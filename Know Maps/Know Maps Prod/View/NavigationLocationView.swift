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
    
    @State private var showPopover:Bool = false
    
    var body: some View {
        GeometryReader { geo in
            Section {
                List(chatModel.filteredDestinationLocationResults, selection:$chatModel.selectedDestinationLocationChatResult) { result in
                    HStack {
                        if let location = result.location, cloudCache.hasPrivateCloudAccess, result.locationName != "Current Location" {
                            let isSaved = chatModel.cachedLocation(contains: chatModel.cachedLocationIdentity(for: location))
                            if isSaved {
                                ZStack {
                                    Capsule()
#if os(macOS)
                                        .foregroundStyle(.background)
                                        .frame(width: 44, height:44)
#else
                                        .foregroundColor(Color(uiColor:.systemFill))
                                        .frame(width: 44, height: 44, alignment: .center).padding(8)
#endif
                                    Label("Save", systemImage: "minus")
                                    
                                        .labelStyle(.iconOnly)
                                }
                                .onTapGesture {
                                    if let cachedLocationResults = chatModel.cachedLocationResults(for: "Location", identity:chatModel.cachedLocationIdentity(for:location)) {
                                        for cachedLocationResult in cachedLocationResults {
                                            Task {
                                                try await cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                                try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
                                            }
                                        }
                                    }
                                }
#if os(iOS) || os(visionOS)
                                .hoverEffect(.lift)
#endif
                            } else {
                                ZStack {
                                    Capsule()
#if os(macOS)
                                        .foregroundStyle(.background)
                                        .frame(width: 44, height:44)
#else
                                        .foregroundColor(Color(uiColor:.systemFill))
                                        .frame(width: 44, height: 44, alignment: .center).padding(8)
#endif
                                    Label("Save", systemImage: "plus")
                                    
                                        .labelStyle(.iconOnly)
                                    
                                }
                                .onTapGesture {
                                    Task {
                                        let userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: result.locationName, icons: "", list: nil)
                                        let _ = try await cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                        chatModel.appendCachedLocation(with: userRecord)
                                    }
                                }
#if os(iOS) || os(visionOS)
                                .hoverEffect(.lift)
#endif
                            }
                        }
                        
                        if result.id == chatModel.selectedDestinationLocationChatResult {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.red)
                        } else if chatModel.selectedDestinationLocationChatResult == nil, result.locationName == "Current Location" {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.red)
                        } else {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.blue)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .toolbar(content: {
                ToolbarItem(placement: .automatic) {
                    Button(showPopover ? "Done" : "Add", systemImage: showPopover ? "checkmark" :"plus") {
                        showPopover.toggle()
                    }.labelStyle(.iconOnly)
                    .padding()
                        .popover(isPresented: $showPopover) {
                            TextField("Search for location name (i.e. 'New York, NY')", text: $chatModel.locationSearchText)
                                .padding()
                                .onSubmit {
                                    showPopover.toggle()
                                    if !chatModel.locationSearchText.isEmpty {
                                        if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult {
                                            Task {
                                                do {
                                                    try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:selectedDestinationLocationChatResult)
                                                } catch {
                                                    chatModel.analytics?.track(name: "error \(error)")
                                                    print(error)
                                                }
                                            }
                                        }
                                        else {
                                            
                                        }
                                    }
                                }
                        }
                }
            })
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
