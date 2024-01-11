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
    @State private var savedSectionSelection = 1
    @State private var sectionSelection = 0

    var body: some View { 
        VStack {
            let hasCachedResults = cloudCache.hasPrivateCloudAccess
                Section {
                    VStack {
                        Picker("", selection: $sectionSelection) {
                            Text("Category").tag(0)
                            Text("Taste").tag(1)
                            if hasCachedResults {
                                Text("Saved").tag(2)
                            }
                        }
                        .padding(8)
                        .pickerStyle(.segmented)
                        switch sectionSelection {
                        case 0:
                            SearchCategoryView(model: model)
                        case 1:
                            SearchTasteView(model: model)
                        case 2:
                            SearchSavedView(model: model)
                        default:
                            ContentUnavailableView("No Tastes", systemImage:"return")
                        }
                    }
                    .onChange(of: model.selectedSavedResult) { oldValue, newValue in
                        if newValue == nil {
                            model.selectedPlaceChatResult = nil
                            return
                        }
                        Task { @MainActor in
                            if let newValue = newValue, let categoricalResult =
                                model.savedCategoricalResult(for: newValue) {
                                model.locationSearchText = model.chatResult(for: newValue)?.title ?? model.locationSearchText
                                await chatHost.didTap(chatResult: categoricalResult)
                            }
                        }
                    }
                    .onChange(of: model.selectedCategoryResult) { oldValue, newValue in
                        if newValue == nil {
                            model.selectedPlaceChatResult = nil
                            return
                        }
                        Task { @MainActor in
                            if let newValue = newValue, let categoricalResult =
                                model.categoricalResult(for: newValue) {
                                model.selectedPlaceChatResult = nil
                                model.locationSearchText = model.chatResult(for: newValue)?.title ?? model.locationSearchText
                                await chatHost.didTap(chatResult: categoricalResult)
                            }
                        }
                    }.task {
                        do {
                            try await model.refreshCachedLocations(cloudCache: cloudCache)
                            try await model.refreshCachedCategories(cloudCache: cloudCache)
                            try await model.refreshCachedTastes(cloudCache: cloudCache)
                        } catch {
                            model.analytics?.track(name: "error \(error)")
                            print(error)
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
    return SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
}
