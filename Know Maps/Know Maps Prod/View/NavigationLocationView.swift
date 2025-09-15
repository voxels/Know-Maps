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
        List(modelController.filteredLocationResults(cacheManager: cacheManager), selection:$modelController.selectedDestinationLocationChatResult) { result in
            let isSaved = cacheManager.cachedLocation(contains:result.locationName)
            HStack {
                if isSaved {
                    Button(action: {
                        if let location = result.location {
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
                        Label(result.locationName, systemImage: "minus.circle")
                    })
                    .labelStyle(.titleAndIcon)
                } else {
                    Button(action: {
                        if let location = result.location {
                            Task(priority:.userInitiated) {
                                do {
                                    try await searchSavedViewModel.addLocation(
                                        parent:result,
                                        location: location,
                                        cacheManager: cacheManager,
                                        modelController: modelController
                                    )
                                    modelController.selectedDestinationLocationChatResult = modelController.filteredLocationResults(cacheManager:cacheManager).first(where: {$0.locationName == result.locationName})?.id
                                } catch {
                                    modelController.analyticsManager.trackError(
                                        error: error,
                                        additionalInfo: nil
                                    )
                                }
                            }
                        }
                    }, label: {
                        Label(result.locationName, systemImage: "plus.circle")
                    })
                    .labelStyle(.titleAndIcon)
                }
                Spacer()
                isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
            }
        }.searchable(text: $searchText)
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
