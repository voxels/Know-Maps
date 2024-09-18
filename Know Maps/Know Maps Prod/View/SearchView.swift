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
        .onChange(of: chatModel.selectedSavedResult) { oldValue, newValue in
            chatModel.resetPlaceModel()
            
            guard let newValue = newValue else {
                return
            }
            
            Task { @MainActor in
                if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                    chatModel.locationSearchText = cachedResult.title
                    await chatHost.didTap(chatResult: cachedResult)
                } else {
                    let parentCategories = chatModel.allCachedResults.filter { result in
                        result.id == newValue
                    }
                    chatModel.locationSearchText = parentCategories.first?.parentCategory ?? chatModel.locationSearchText
                    
                    if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult {
                        do {
                            try await chatModel.didSearch(caption: chatModel.locationSearchText, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
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
                    await chatHost.didTap(chatResult: categoricalResult)
                }
            }
        }.onChange(of: chatModel.selectedTasteCategoryResult, { oldValue, newValue in
            chatModel.resetPlaceModel()
            Task { @MainActor in
                if let newValue = newValue, let tasteResult = chatModel.tasteResult(for: newValue) {
                    chatModel.locationSearchText = tasteResult.title
                    await chatHost.didTap(chatResult: tasteResult)
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