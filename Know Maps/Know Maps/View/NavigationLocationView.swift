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
    @Binding public var resultId:ChatResult.ID?

    var body: some View {
        GeometryReader { geo in
            VStack() {
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
                                Button("Save", systemImage: "star.fill") {
                                    if let cachedLocationResults = chatModel.cachedLocationResults(for: "Location", identity:chatModel.cachedLocationIdentity(for:location)) {
                                        for cachedLocationResult in cachedLocationResults {
                                            Task { @MainActor in
                                                try await cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                                try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
                                            }
                                        }
                                    }
                                }.labelStyle(.iconOnly)
                            } else {
                                Button("Save", systemImage: "star") {
                                    Task {
                                        let _ = try await cloudCache.storeUserCachedRecord(for: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: result.locationName)
                                        try await chatModel.refreshCachedLocations(cloudCache: cloudCache)
                                    }
                                }.labelStyle(.iconOnly)
                            }
                        }

                    }
                }
                .autocorrectionDisabled(true)
                .searchable(text: $chatModel.locationSearchText, isPresented:$searchIsPresented)
                .onSubmit(of: .search, {
                    if chatModel.locationSearchText.isEmpty, !chatModel.placeResults.isEmpty {
                        chatModel.resetPlaceModel()
                        chatModel.selectedCategoryChatResult = nil
                        chatModel.selectedSavedCategoryResult = nil
                    } else {
                        Task {
                            do {
                                try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    }
                }).onChange(of: chatModel.locationSearchText, { oldValue, newValue in
                    if newValue.isEmpty {
                        chatModel.resetPlaceModel()
                        chatModel.selectedCategoryChatResult = nil
                        chatModel.selectedSavedCategoryResult = nil
                    }
                })
                .onChange(of: chatModel.selectedDestinationLocationChatResult, { oldValue, newValue in
                    
                    if let newValue = newValue, let locationChatResult = chatModel.locationChatResult(for: newValue),  !chatModel.locationSearchText.lowercased().contains(locationChatResult.locationName.lowercased()) {
                        chatModel.locationSearchText = locationChatResult.locationName
                        chatModel.selectedCategoryResult = nil
                        chatModel.selectedSavedCategoryResult = nil
                        Task {
                            do {
                                try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    }
                })
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()

    let chatHost = AssistiveChatHost()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)

    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel

    return NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
