//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @Environment(\.dismiss) var dismiss

    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var showNavigationLocationView:Bool
    @State private var searchIsPresented = false
    @State private var searchText:String = ""
    var body: some View {
            VStack {
                HStack {
                    Button(action:{
                        dismiss()
                    }, label:{
                        Text("Dismiss")
                    }).padding()
                    Spacer()
                }
                TextField("Search for a city/state or address", text: $searchText)
                    .onSubmit(of: .text) {
                        search(intent:.Location)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding()
                Spacer()
                List(modelController.filteredLocationResults(cacheManager: cacheManager), selection:$modelController.selectedDestinationLocationChatResult) { result in
                    let isSaved = cacheManager.cachedLocation(contains:result.locationName)
                    HStack {
                        if result.id == modelController.selectedDestinationLocationChatResult {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.red)
                        } else {
                            Label(result.locationName, systemImage: "mappin")
                                .tint(.blue)
                        }
                        Spacer()
                        isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let parent =  modelController.locationChatResult(
                        for: selectedDestinationLocationChatResult,in: modelController.filteredLocationResults(cacheManager: cacheManager)) {
                        let isSaved = cacheManager.cachedLocation(contains: parent.locationName)
                        if isSaved {
                            Button(action: {
                                if let location = parent.location {
                                    Task(priority:.userInitiated) {
                                        await searchSavedViewModel.removeCachedResults(
                                            group: "Location",
                                            identity: cacheManager.cachedLocationIdentity(for: location),
                                            cacheManager: cacheManager,
                                            modelController: modelController
                                        )
                                    }
                                }
                            }, label: {
                                Label("Delete", systemImage: "minus.circle")
                            })
                            .labelStyle(.titleAndIcon)
                        } else {
                            Button(action: {
                                if let location = parent.location {
                                    Task(priority:.userInitiated) {
                                        do {
                                            try await searchSavedViewModel.addLocation(
                                                parent: parent,
                                                location: location,
                                                cacheManager: cacheManager,
                                                modelController: modelController
                                            )
                                            modelController.selectedDestinationLocationChatResult = modelController.filteredLocationResults(cacheManager:cacheManager).first(where: {$0.locationName == parent.locationName})?.id
                                        } catch {
                                            modelController.analyticsManager.trackError(
                                                error: error,
                                                additionalInfo: nil
                                            )
                                        }
                                    }
                                }
                            }, label: {
                                Label("Save", systemImage: "plus.circle")
                            })
                            .labelStyle(.titleAndIcon)
                        }
                    }
                }.padding()
            }.padding()
    }
    
    func search(intent:AssistiveChatHostService.Intent) {
        if !searchText.isEmpty {
            Task(priority:.userInitiated) {
                await searchSavedViewModel.search(
                    caption: searchText,
                    selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult, intent: intent, filters: searchSavedViewModel.filters,
                    chatModel: chatModel,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
            }
        }
    }
}
