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
            Section {
                VStack {
                    Picker("", selection: $sectionSelection) {
                        Text("Category").tag(0)
                        Text("Taste").tag(1)
                        Text("Saved").tag(2)
                    }
                    .padding(8)
                    .pickerStyle(.segmented)
                    switch sectionSelection {
                    case 0:
                        SearchCategoryView(model: model)
                            .compositingGroup()
                    case 1:
                        SearchTasteView(model: model)
                            .compositingGroup()
                    case 2:
                        SearchSavedView(model: model)
                            .compositingGroup()
                    default:
                        ContentUnavailableView("No Tastes", systemImage:"return")
                    }
                }
                .onChange(of: model.selectedSavedResult) { oldValue, newValue in
                    
                    model.resetPlaceModel()
                    
                    guard let newValue = newValue else {
                        return
                    }
                    
                    Task { @MainActor in
                        if let cachedResult = model.cachedChatResult(for: newValue) {
                            model.locationSearchText = cachedResult.title
                            await chatHost.didTap(chatResult: cachedResult)
                        } else {
                            let parentCategories = model.allCachedResults.filter { result in
                                result.id == newValue
                            }
                            model.locationSearchText = parentCategories.first?.parentCategory ?? model.locationSearchText
                            
                            if let selectedDestinationLocationChatResult = model.selectedDestinationLocationChatResult {
                                do {
                                    try await model.didSearch(caption: model.locationSearchText, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                                } catch {
                                    model.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            } else {
                                model.selectedDestinationLocationChatResult = model.filteredLocationResults.first?.id
                                
                                guard let selectedDestinationLocationChatResult = model.selectedDestinationLocationChatResult else {
                                    return
                                }
                                
                                do {
                                    try await model.didSearch(caption: model.locationSearchText, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                                } catch {
                                    model.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }
                    }
                }
                .onChange(of: model.selectedCategoryResult) { oldValue, newValue in
                    model.resetPlaceModel()
                Task { @MainActor in
                        if let newValue = newValue, let categoricalResult =
                            model.categoricalResult(for: newValue) {
                            model.locationSearchText = model.categoricalResult(for: newValue)?.title ?? model.locationSearchText
                            await chatHost.didTap(chatResult: categoricalResult)
                        }
                    }
                }.onChange(of: model.selectedTasteCategoryResult, { oldValue, newValue in
                        model.resetPlaceModel()
                    Task { @MainActor in
                        if let newValue = newValue, let tasteResult = model.tasteResult(for: newValue) {
                            model.locationSearchText = tasteResult.title
                            await chatHost.didTap(chatResult: tasteResult)
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
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    return SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
}
