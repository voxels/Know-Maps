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

public enum SearchMode: Hashable {
    case favorites
    case industries
    case features
    case places
}

public struct ContentView: View {
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
    var chatModel:ChatResultViewModel
    var cacheManager:CloudCacheManager
    var modelController:DefaultModelController
    var searchSavedViewModel:SearchSavedViewModel
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
    public var body: some View {
        GeometryReader { geometry in
            browseView()
                .sheet(isPresented: $showSettings, content: {
                    VStack(alignment: .leading) {
                        SettingsView(model: settingsModel, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, showOnboarding: $showOnboarding)
                            .padding()
                        HStack{
                            Spacer()
                            Button("Done") {
                                showSettings.toggle()
                            }
                            .padding()
                            #if !os(visionOS)
//                            .glassEffect()
                            #endif
                        }
                    }
                    .padding()
                    .presentationDetents([.large])
                })
                .onChange(of:modelController.selectedCategoryChatResult) {_, newValue in
                    if let selectedID = newValue {
                        Task { @MainActor in
                            await modelController.handleCategorySelection(for: selectedID)
                        }
                    }
                }
                .tabViewStyle(.tabBarOnly)
                .sheet(item: Binding(
                    get: { searchSavedViewModel.editingRecommendationWeightResult },
                    set: { searchSavedViewModel.editingRecommendationWeightResult = $0 }
                )) { selectedResult in
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
                        
                        // **FIX**: Compute the caption and capture the destination ID within a single @MainActor block
                        // to prevent data races when accessing modelController properties from a background task.
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
        // --- Common Toolbar Views ---
        let settingsButton = Button {
            showSettings.toggle()
        } label: {
            Label("Settings", systemImage: "person.crop.circle")
        }

        let searchModePicker = Picker("Search Mode", selection: $searchMode) {
            Text("❤️").accessibilityLabel("Favorites").tag(SearchMode.favorites)
            Text("🏭").accessibilityLabel("Industries").tag(SearchMode.industries)
            Text("✨").accessibilityLabel("Features").tag(SearchMode.features)
            Text("📍").accessibilityLabel("Places").tag(SearchMode.places)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .tint(.accentColor)

        let filterButton = Button {
            if !showNavigationLocationView { showNavigationLocationView = true }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
        .disabled(showNavigationLocationView)

        // --- Platform-Specific Placement ---
#if os(macOS)
        ToolbarItem(placement: .navigation) {
            settingsButton
        }
        ToolbarItem(placement: .principal) {
            searchModePicker
        }
        ToolbarItem(placement: .status) {
            filterButton
        }
#elseif os(iOS) || os(tvOS)
        ToolbarItem(placement: .topBarLeading) {
            settingsButton.labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .bottomBar) {
            searchModePicker
        }
        ToolbarItem(placement: .topBarTrailing) {
            filterButton
        }
#elseif os(visionOS)
        ToolbarItem(placement: .topBarLeading) {
            settingsButton.labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .bottomOrnament) {
            searchModePicker
        }
        ToolbarItem(placement: .topBarTrailing) {
            filterButton
        }
#else
        // Fallback for other platforms
        ToolbarItem(placement: .topBarLeading) {
            settingsButton.labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .principal) {
            searchModePicker
        }
        ToolbarItem(placement: .topBarTrailing) {
            filterButton
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
                    SearchView(chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, searchSavedViewModel: searchSavedViewModel, searchMode:$searchMode)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .industries:
                    SearchCategoryView(chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, searchSavedViewModel: searchSavedViewModel, multiSelection: $multiSelection, section: Binding(get: { modelController.section }, set: { modelController.section = $0 }))
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .features:
                    SearchTasteView(chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, searchSavedViewModel: searchSavedViewModel, multiSelection: $multiSelection, section: Binding(get: { modelController.section }, set: { modelController.section = $0 }))
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .places:
                    SearchPlacesView(searchSavedViewModel: searchSavedViewModel, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, multiSelection: $multiSelection, placeDirectionsChatViewModel: placeDirectionsChatViewModel)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                }
            } detail: {
                Group {
                    if let selectedFsqId = modelController.selectedPlaceChatResultFsqId,
                       let placeChatResult = modelController.placeChatResult(with: selectedFsqId) {
                        PlaceView(
                            searchSavedViewModel: searchSavedViewModel,
                            chatModel: chatModel,
                            cacheManager: cacheManager,
                            modelController: modelController,
                            placeDirectionsViewModel: placeDirectionsChatViewModel,
                            selectedResult: placeChatResult
                        )
                        .navigationTitle(placeChatResult.title)
                    } else {
                        PlacesList(
                            searchSavedViewModel: searchSavedViewModel,
                            chatModel: chatModel,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                    }
                }
                .id(modelController.selectedPlaceChatResultFsqId ?? "places-list")
            }
        }
        .task {
            await modelController.ensureIndustryResultsPopulated()
            await modelController.ensureTasteResultsPopulated()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
