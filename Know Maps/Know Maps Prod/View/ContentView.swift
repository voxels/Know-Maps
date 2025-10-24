//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import Segment
import MapKit
import TipKit


struct MenuNavigationIconTip: Tip {
    var title: Text {
        Text("Favorites Tab")
    }
    
    
    var message: Text? {
        Text("Add industries, features, and places to your favorites tab.")
    }
    
    
    var image: Image? {
        Image(systemName: "heart.fill")
    }
}


public enum ContentDetailView {
    case home
    case add
}

enum SearchMode: Hashable {
    case favorites
    case industries
    case features
    case places
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @ObservedObject var settingsModel:AppleAuthenticationService
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @Binding var showOnboarding:Bool
    @Binding var showNavigationLocationView:Bool
    @Binding var searchMode: SearchMode
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State public var lastMultiSelection = Set<String>()
    @State public var multiSelection = Set<String>()
    
    @State private var showFiltersSheet:Bool = false
    @State private var showSettingsSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedMapItem:String?
    @State private var showAddRecommendationView:Bool = false
    
    @State private var showSettings:Bool = false
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "Current Location")
    
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var preferredCompactColumn:NavigationSplitViewColumn = .detail
    var body: some View {
        GeometryReader { geometry in
            browseView()
                .popover(isPresented: $showSettings, content: {
                    SettingsView(model: settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
                })
                .onChange(of:modelController.selectedCategoryChatResult) {_, newValue in
                    if let id = newValue {
                        Task {
                            // Try to resolve an industry category result first (live, then cached)
                            if let industryCategory = modelController.industryCategoryResult(for: id) ??
                                                       modelController.cachedIndustryResult(for: id),
                               let chatResult = modelController.cachedChatResult(for: industryCategory.id) {
                                do {
                                    try await handleIndustryCategoryChatResult(chatResult)
                                } catch {
                                    modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                                }
                                return
                            }

                            // Then try a taste category result (live, then cached)
                            if let tasteCategory = modelController.tasteCategoryResult(for: id) ??
                                                   modelController.cachedTasteResult(for: id),
                               let chatResult = modelController.cachedChatResult(for: tasteCategory.id) {
                                do {
                                    try await handleTasteCategoryChatResult(chatResult)
                                } catch {
                                    modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                                }
                                return
                            }

                            // Then try a place result from cache
                            if let placeResult = modelController.cachedPlaceResult(for: id) {
                                // If we can resolve a corresponding place chat result, treat this category as a place
                                if let placeChat = placeResult.categoricalChatResults.first {
                                    do {
                                        try await handlePlaceCategoryChatResult(placeChat)
                                    } catch {
                                        modelController.analyticsManager.trackError(error: error, additionalInfo: ["phase": "placeSelectionTap"])
                                    }
                                    return
                                } else {
                                    // No direct place chat found; fall back to a search using the category caption
                                    do {
                                        let caption = placeResult.parentCategory
                                        let selectedDestination = modelController.selectedDestinationLocationChatResult
                                        let intentKind = AssistiveChatHostService.Intent.Search
                                        let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption, filters: [:])
                                        let newIntent = AssistiveChatHostIntent(
                                            caption: caption,
                                            intent: intentKind,
                                            selectedPlaceSearchResponse: nil,
                                            selectedPlaceSearchDetails: nil,
                                            placeSearchResponses: [],
                                            selectedDestinationLocation: selectedDestination,
                                            placeDetailsResponses: nil,
                                            queryParameters: queryParameters
                                        )
                                        await modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
                                        try await modelController.searchIntent(intent: newIntent)
                                    } catch {
                                        modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                                    }
                                }
                            }

                            // Finally, fall back to a generic chat result
                            if let chatResult = modelController.cachedChatResult(for: id) {
                                do {
                                    let caption = chatResult.title
                                    let selectedDestination = modelController.selectedDestinationLocationChatResult
                                    let intentKind = AssistiveChatHostService.Intent.Search
                                    let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption, filters: [:])
                                    let newIntent = AssistiveChatHostIntent(
                                        caption: caption,
                                        intent: intentKind,
                                        selectedPlaceSearchResponse: nil,
                                        selectedPlaceSearchDetails: nil,
                                        placeSearchResponses: [],
                                        selectedDestinationLocation: selectedDestination,
                                        placeDetailsResponses: nil,
                                        queryParameters: queryParameters
                                    )
                                    await modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
                                    try await modelController.searchIntent(intent: newIntent)
                                } catch {
                                    modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                                }
                            }
                        }
                    }
                }
#if !os(visionOS) && !os(macOS)
                .containerBackground(Color(.clear), for: .navigation)
#endif
                .tabViewStyle(.tabBarOnly)
                .sheet(item: $searchSavedViewModel.editingRecommendationWeightResult) { selectedResult in
                    recommendationWeightSheet(for: selectedResult)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled(false)
                        .presentationCompactAdaptation(.sheet)
                }
                .onAppear(perform: {
                    modelController.analyticsManager.track(event:"ContentView",properties: nil )
                })
                .onDisappear { searchTask?.cancel() }
                .onChange(of: multiSelection) { oldValue, newValue in
                    // Cancel any existing task
                    searchTask?.cancel()
                    
                    searchTask = Task(priority: .userInitiated) {
                        // Capture the newValue to avoid data races
                        let selections = newValue
                        
                        // Early cancellation
                        try? Task.checkCancellation()
                        
                        // Compute the caption and capture the destination ID with a single @MainActor hop
                        let (caption, selectedDestination): (String, LocationResult) = await MainActor.run {
                            let tasteCaption = selections.compactMap { id in
                                modelController.tasteCategoryResult(for: id)?.parentCategory
                            }.joined(separator: ",")
                            
                            let categoryCaption = selections.compactMap { id in
                                modelController.industryCategoryResult(for: id)?.parentCategory
                            }.joined(separator: ",")
                            
                            let caption: String = {
                                if tasteCaption.isEmpty && categoryCaption.isEmpty {
                                    return ""
                                } else if !tasteCaption.isEmpty && !categoryCaption.isEmpty {
                                    return "\(tasteCaption), \(categoryCaption)"
                                } else if !tasteCaption.isEmpty {
                                    return tasteCaption
                                } else {
                                    return categoryCaption
                                }
                            }()
                            
                            return (caption, modelController.selectedDestinationLocationChatResult)
                        }
                        
                        // Nothing to search for
                        if caption.isEmpty { return }
                        
                        try? Task.checkCancellation()
                        
                        // Flip the refreshing flag and guarantee it resets
                        await MainActor.run { modelController.isRefreshingPlaces = true }
                        defer {
                            Task { @MainActor in
                                modelController.isRefreshingPlaces = false
                            }
                        }
                        
                        do {
                            try? Task.checkCancellation()
                            
                            let intentKind = AssistiveChatHostService.Intent.Search
                            let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption, filters: [:])
                            let newIntent = AssistiveChatHostIntent(
                                caption: caption,
                                intent: intentKind,
                                selectedPlaceSearchResponse: nil,
                                selectedPlaceSearchDetails: nil,
                                placeSearchResponses: [],
                                selectedDestinationLocation: selectedDestination,
                                placeDetailsResponses: nil,
                                queryParameters: queryParameters
                            )
                            await modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
                            try await modelController.searchIntent(intent: newIntent)
                        } catch is CancellationError {
                            // Swallow cancellations silently
                        } catch {
                            await MainActor.run {
                                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                            }
                        }
                    }
                }
        }
    }
    
    
    @ToolbarContentBuilder
    func unifiedBrowseToolbar() -> some ToolbarContent {
#if os(macOS)
        ToolbarItem(placement: .secondaryAction) {
            Picker("Search Mode", selection: $searchMode) {
                Text("❤️").accessibilityLabel("Favorites").tag(SearchMode.favorites)
                Text("🏭").accessibilityLabel("Industries").tag(SearchMode.industries)
                Text("✨").accessibilityLabel("Features").tag(SearchMode.features)
                Text("📍").accessibilityLabel("Places").tag(SearchMode.places)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .tint(.accentColor)
        }
#else
        ToolbarItem(placement: .automatic) {
            Picker("Search Mode", selection: $searchMode) {
                Text("❤️").accessibilityLabel("Favorites").tag(SearchMode.favorites)
                Text("🏭").accessibilityLabel("Industries").tag(SearchMode.industries)
                Text("✨").accessibilityLabel("Features").tag(SearchMode.features)
                Text("📍").accessibilityLabel("Places").tag(SearchMode.places)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .tint(.accentColor)
        }
#endif
        
#if os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if !showNavigationLocationView {
                    showNavigationLocationView = true
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease")
            }
            .disabled(showNavigationLocationView)
        }
#else
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                if !showNavigationLocationView {
                    showNavigationLocationView = true
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease")
            }
            .disabled(showNavigationLocationView)
            Button("Settings", systemImage: "person.crop.circle") {
                showSettings.toggle()
            }
            .labelStyle(.iconOnly)

        }
#endif
    }
    
    @ViewBuilder
    func recommendationWeightSheet(for selectedResult: CategoryResult) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(selectedResult.parentCategory)
                .font(.headline)
                .padding()
            
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 0, cacheManager: cacheManager, modelController: modelController)
                showAddRecommendationView = false
            }) {
                Label("Recommend rarely", systemImage: "star.slash")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 2, cacheManager: cacheManager, modelController: modelController)
                showAddRecommendationView = false
                
            }) {
                Label("Recommend occasionally", systemImage: "star.leadinghalf.filled")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 3,  cacheManager: cacheManager, modelController: modelController)
                showAddRecommendationView = false
            }) {
                Label("Recommend often", systemImage: "star.fill")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            Spacer()
        }
    }
    
    func browseView() -> some View {
        VStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                switch searchMode {
                case .favorites:
                    SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, searchMode:$searchMode)
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .industries:
                    SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection, section:$modelController.section)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .features:
                    SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection,  section:$modelController.section)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .places:
                    SearchPlacesView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, multiSelection: $multiSelection, placeDirectionsChatViewModel: placeDirectionsChatViewModel)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                }
            } detail: {
                if let selectedResult = modelController.selectedPlaceChatResultFsqId, let placeChatResult = modelController.placeChatResult(with: selectedResult) {
                    PlaceView(
                        searchSavedViewModel: $searchSavedViewModel,
                        chatModel: $chatModel,
                        cacheManager: $cacheManager,
                        modelController: $modelController,
                        placeDirectionsViewModel: placeDirectionsChatViewModel,
                        selectedResult: placeChatResult
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(placeChatResult.title)
                } else {
                    PlacesList(
                        searchSavedViewModel: $searchSavedViewModel,
                        chatModel: $chatModel,
                        cacheManager: $cacheManager,
                        modelController: $modelController
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Browse")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentView {
    // MARK: - Category Handling
    private func handlePlaceCategoryChatResult(_ result:ChatResult) async throws {
        Task {
            do {
                if let selectedPlaceSearchResponse = result.placeResponse {
                    
                    let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: result.title, filters: searchSavedViewModel.filters)
                    
                    let intent = AssistiveChatHostIntent(caption: result.title, intent: .Place, selectedPlaceSearchResponse: result.placeResponse, selectedPlaceSearchDetails: result.placeDetailsResponse, placeSearchResponses:[], selectedDestinationLocation:modelController.selectedDestinationLocationChatResult, placeDetailsResponses:nil, queryParameters: queryParameters)
                    try await modelController.searchIntent(intent: intent)
                }
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
    }
    
    private func handleIndustryCategoryChatResult(_ result:ChatResult) async throws {
        try await handleListCategoryChatResult(result)
    }
    
    private func handleTasteCategoryChatResult(_ result:ChatResult) async throws {
        try await handleListCategoryChatResult(result)
    }
    
    private func handleDefaultCategoryChatResult(_ result:ChatResult) async throws {
        try await handleListCategoryChatResult(result)
    }
    
    private func handleListCategoryChatResult(_ result:ChatResult) async throws {
        let caption = result.title
        let selectedDestination = modelController.selectedDestinationLocationChatResult
        let intentKind = AssistiveChatHostService.Intent.Search
        let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption, filters: [:])
        let newIntent = AssistiveChatHostIntent(
            caption: caption,
            intent: intentKind,
            selectedPlaceSearchResponse: nil,
            selectedPlaceSearchDetails: nil,
            placeSearchResponses: [],
            selectedDestinationLocation: selectedDestination,
            placeDetailsResponses: nil,
            queryParameters: queryParameters
        )
        await modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
        try await modelController.searchIntent(intent: newIntent)
    }
}

