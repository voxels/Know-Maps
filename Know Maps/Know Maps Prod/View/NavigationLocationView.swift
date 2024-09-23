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
                    HStack {
                        if let location = result.location, cloudCache.hasPrivateCloudAccess{
                            let isSaved = chatModel.cachedLocation(contains: result.locationName)
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
                                    if let cachedLocationResults = chatModel.cachedLocationResults(for: "Location", identity:result.locationName) {
                                        Task {
                                        for cachedLocationResult in cachedLocationResults {
                                            
                                                try await cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                            }
                                                                                            try await chatModel.refreshCachedLocations(cloudCache: cloudCache)

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
                                    Task(priority: .userInitiated) {
                                        var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: result.locationName, icons: "", list: nil)
                                        let record = try await cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                        userRecord.setRecordId(to:record)
                                        
                                        chatModel.appendCachedLocation(with: userRecord)
                                        try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
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
                        if showPopover {
                            chatModel.locationSearchText.removeAll()
                        }
                    }.labelStyle(.iconOnly)
                    .padding()
                        .alert("Location Search", isPresented: $showPopover) {
                            VStack {
                                TextField("New York, NY", text: $searchText)
                                    .padding()
                                Button(action:{
                                    if !searchText.isEmpty {
                                            Task {
                                                do {
                                                    try await chatModel.didSearch(caption:searchText, selectedDestinationChatResultID:nil, intent:.Location)
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
