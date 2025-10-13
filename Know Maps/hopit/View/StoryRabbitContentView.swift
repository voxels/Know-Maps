//
//  StoryRabbitContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/23/25.
//

import SwiftUI
import AVKit


struct StoryRabbitContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @ObservedObject var settingsModel:AppleAuthenticationService
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @Binding  public var showOnboarding:Bool
    
    @State public var lastMultiSelection = Set<UUID>()
    @State public var multiSelection = Set<UUID>()
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            TabView {
                StoryRabbitMapView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel)
                    .tabItem {
                        Label("Explore", systemImage: "globe.americas")
                    }
                StoryRabbitSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .onAppear(perform: {
                modelController.analyticsManager.track(event:"StoryRabbitContentView",properties: nil )
            })
            .onChange(of: modelController.selectedDestinationLocationChatResult, { oldValue, newValue in
                if newValue != nil {
                    modelController.selectedSavedResult = nil
                    Task(priority:.userInitiated) {
                        do {
                            try await modelController.resetPlaceModel()
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                }
            })
            .onChange(of: multiSelection) { oldValue, newValue in
                
                // Cancel any existing task
                searchTask?.cancel()
                
                searchTask = Task(priority: .userInitiated) {
                    // Capture the newValue to avoid data races
                    let selections = newValue
                    
                    // Check for cancellation before proceeding
                    guard !Task.isCancelled else { return }
                    
                    let tasteCaption = selections.compactMap { selection in
                        modelController.tasteCategoryResult(for: selection)?.parentCategory
                    }.joined(separator: ",")
                    
                    let categoryCaption = selections.compactMap { selection in
                        modelController.industryCategoryResult(for: selection)?.parentCategory
                    }.joined(separator: ",")
                    
                    let caption = "\(tasteCaption), \(categoryCaption)"
                    
                    // Check for cancellation again before the async call
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run {
                        modelController.isRefreshingPlaces = true
                    }
                    do {
                        try await modelController.resetPlaceModel()
                        try await chatModel.didSearch(
                            caption: caption,
                            selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult,
                            filters: searchSavedViewModel.filters,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                        await MainActor.run {
                            modelController.isRefreshingPlaces = false
                        }
                    } catch {
                        await MainActor.run {
                            modelController.isRefreshingPlaces = false
                        }
                        modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                    }
                }
            }
            .onChange(of: modelController.selectedPlaceChatResult, { oldValue, newValue in
                guard let newValue else {
                    return
                }
                
                Task { @MainActor in
                    if let placeChatResult = modelController.placeChatResult(for: newValue), placeChatResult.placeDetailsResponse == nil {
                        Task(priority: .userInitiated) {
                            do {
                                try await chatModel.didTap(placeChatResult: placeChatResult, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                            } catch {
                                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                            }
                        }
                    }
                    
                }
            })
        }
    }
}
