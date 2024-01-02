//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @State private var searchIsPresented = false
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?

    var body: some View {
        GeometryReader { geo in
            VStack() {
                Section("Search Location") {
                    List(chatModel.filteredDestinationLocationResults, selection:$chatModel.selectedDestinationLocationChatResult) { result in
                        if result.id == chatModel.selectedDestinationLocationChatResult {
                            Label(result.locationName, systemImage: "mappin").tint(.red)
                        } else {
                            Label(result.locationName, systemImage: "mappin").tint(.blue)
                        }
                    }
                }
                .autocorrectionDisabled(true)
                .searchable(text: $chatModel.locationSearchText, isPresented:$searchIsPresented)
                .onSubmit(of: .search, {
                    if chatModel.locationSearchText.isEmpty, !chatModel.placeResults.isEmpty {
                        chatModel.resetPlaceModel()
                        chatModel.selectedCategoryChatResult = nil
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
                    }
                })
                .onChange(of: chatModel.selectedDestinationLocationChatResult, { oldValue, newValue in
                    
//                    chatModel.selectedSourceLocationChatResult = chatModel.filteredLocationResults.first?.id
                    
                    if let newValue = newValue, let locationChatResult = chatModel.locationChatResult(for: newValue),  !chatModel.locationSearchText.lowercased().contains(locationChatResult.locationName.lowercased()) {
                        chatModel.locationSearchText = locationChatResult.locationName
                    }
                })
                
                Section("Departing Location") {
                    List(chatModel.filteredSourceLocationResults, selection:$chatModel.selectedSourceLocationChatResult) { result in
                        if result.id == chatModel.selectedSourceLocationChatResult {
                            Label(result.locationName, systemImage: "mappin").tint(.red)
                        } else {
                            Label(result.locationName, systemImage: "mappin").tint(.blue)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cache = CloudCache()
    let chatHost = AssistiveChatHost(cache:cache)
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cache)
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel

    return NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
