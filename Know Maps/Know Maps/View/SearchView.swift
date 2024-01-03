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
    @ObservedObject public var model:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider

    var body: some View { 
        Section("Categories") {
            List(model.filteredResults, children:\.children, selection:$model.selectedCategoryResult) { parent in
                HStack {
                    Text("\(parent.parentCategory)")
                    Spacer()
                    if let chatResults = parent.categoricalChatResults, chatResults.count == 1, cloudCache.hasPrivateCloudAccess {
                        let isSaved = model.cachedCategories(contains: parent.parentCategory)
                        Button("Save", systemImage:isSaved ? "star.fill" : "star", action: {
                            cloudCache.storeUserCachedRecord(for: "Category", identity: parent.parentCategory, title: parent.parentCategory)
                            Task { @MainActor in
                                try await model.refreshCachedCategories(cloudCache: cloudCache)
                            }
                        }).labelStyle(.iconOnly)
                    }
                }
            }
            .onChange(of: model.selectedCategoryResult) { oldValue, newValue in
                if newValue == nil {
                    model.selectedPlaceChatResult = nil
                }
                Task { @MainActor in
                    if let newValue = newValue, let categoricalResult =
                        model.categoricalResult(for: newValue) {
                        model.locationSearchText = model.chatResult(for: newValue)?.title ?? model.locationSearchText
                        await chatHost.didTap(chatResult: categoricalResult)
                    }
                }
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
    return SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
}
