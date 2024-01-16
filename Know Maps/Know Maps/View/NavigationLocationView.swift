//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @Binding public var columnVisibility:NavigationSplitViewVisibility
    @State private var searchIsPresented = true
    @EnvironmentObject public var cloudCache:CloudCache
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    
    var body: some View {
        GeometryReader { geo in
            List(chatModel.filteredDestinationLocationResults, selection:$chatModel.selectedDestinationLocationChatResult) { result in
                HStack {
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
                    Spacer()
                    if let location = result.location, cloudCache.hasPrivateCloudAccess, result.locationName != "Current Location" {
                        let isSaved = chatModel.cachedLocation(contains: chatModel.cachedLocationIdentity(for: location))
                        if isSaved {
                            Label("Save", systemImage: "star.fill")
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
                                .labelStyle(.iconOnly)
                        } else {
                            Label("Save", systemImage: "star")
                                .onTapGesture {
                                    Task {
                                        let _ = try await cloudCache.storeUserCachedRecord(for: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: result.locationName)
                                        try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
                                    }
                                }
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .onAppear {
                    if let cachedLocationRecords = chatModel.cachedLocationRecords, cachedLocationRecords.isEmpty {
                        Task {
                            do {
                                try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    } else if chatModel.cachedLocationRecords == nil {
                        Task {
                            do {
                                try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
                            } catch {
                                if error as? CloudCacheError == CloudCacheError.ThrottleRequests {
                                    print("Throttled Request")
                                } else {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }
                    }
                }
                .autocorrectionDisabled(true)
                .searchable(text: $chatModel.locationSearchText, isPresented:$searchIsPresented)
                .onSubmit(of: .search, {

                        if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult{
                            Task {
                                do {
                                    try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:selectedDestinationLocationChatResult)
                                    
                                } catch {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        } else {
                            chatModel.selectedDestinationLocationChatResult = chatModel.filteredLocationResults.first?.id
                        }
                
                }).onChange(of: chatModel.locationSearchText, { oldValue, newValue in
                    if newValue.isEmpty {
                        chatModel.resetPlaceModel()
                    }
                }).onChange(of: chatModel.selectedDestinationLocationChatResult) { oldValue, newValue in

                    if let newValue = newValue
                    {
                        Task {
                            do {
                                try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:newValue)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
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
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return NavigationLocationView(columnVisibility: .constant(NavigationSplitViewVisibility.all), chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
