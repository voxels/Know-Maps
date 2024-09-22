//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var cloudCache:CloudCache
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var savedSectionSelection = 1
    @State private var didError = false
    
    var body: some View {
        VStack {
            SearchSavedView(chatHost:chatHost, chatModel: chatModel, locationProvider: locationProvider)
        }
        .onChange(of: chatModel.selectedDestinationLocationChatResult, { oldValue, newValue in
            chatModel.resetPlaceModel()
            
            guard let newValue = newValue else {
                return
            }
            
            Task { @MainActor in
                if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult {
                    if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                        chatModel.locationSearchText = cachedResult.title
                        await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                    }
                } else {
                    if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                        chatModel.locationSearchText = cachedResult.title
                        await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: chatModel.currentLocationResult.id)
                    }
                }
            }
        })
        .onChange(of: chatModel.selectedSavedResult) { oldValue, newValue in
            chatModel.resetPlaceModel()
            
            guard let newValue = newValue else {
                return
            }
            
            Task { @MainActor in
                if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult {
                    if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                        chatModel.locationSearchText = cachedResult.title
                        await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                    } else {
                        do {
                            try await chatModel.didSearch(caption: chatModel.locationSearchText, selectedDestinationChatResultID: selectedDestinationLocationChatResult, intent:.Location)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                } else {
                    if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                        chatModel.locationSearchText = cachedResult.title
                        await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: chatModel.currentLocationResult.id)
                    } else {
                        do {
                            try await chatModel.didSearch(caption: chatModel.locationSearchText, selectedDestinationChatResultID: chatModel.currentLocationResult.id, intent:.Location)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }
        }
        .onChange(of: chatModel.selectedCategoryResult) { oldValue, newValue in
            chatModel.resetPlaceModel()
            Task { @MainActor in
                if let newValue = newValue, let categoricalResult =
                    chatModel.categoricalResult(for: newValue) {
                    chatModel.locationSearchText = chatModel.categoricalResult(for: newValue)?.title ?? chatModel.locationSearchText
                    await chatHost.didTap(chatResult: categoricalResult, selectedDestinationChatResultID: chatModel.selectedDestinationLocationChatResult ?? chatModel.currentLocationResult.id)
                }
            }
        }.onChange(of: chatModel.selectedTasteCategoryResult, { oldValue, newValue in
            chatModel.resetPlaceModel()
            Task { @MainActor in
                if let newValue = newValue, let tasteResult = chatModel.tasteResult(for: newValue) {
                    chatModel.locationSearchText = tasteResult.title
                    await chatHost.didTap(chatResult: tasteResult, selectedDestinationChatResultID: chatModel.selectedDestinationLocationChatResult ?? chatModel.currentLocationResult.id)
                }
            }
        })
    }
}

#Preview {
    
    let locationProvider = LocationProvider()
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    return SearchView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
}
