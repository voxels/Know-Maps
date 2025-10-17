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
    @State private var selectedCategoryID:CategoryResult.ID?
    @State public var lastMultiSelection = Set<String>()
    @State public var multiSelection = Set<String>()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    
    @State private var showFiltersSheet:Bool = false
    @State private var showSettingsSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedMapItem:String?
    @State private var showAddRecommendationView:Bool = false
    @State private var placesPath = NavigationPath()
    @State private var lastPushedPlaceID: ChatResult.ID? = nil
    
    @State private var showPlaceList: Bool = true
    @State private var showSettings:Bool = false
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "Current Location")
    
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geometry in
            browseView()
            .popover(isPresented: $showSettings, content: {
                SettingsView(model: settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
            })
            .onChange(of: modelController.selectedPlaceChatResult) { _, newValue in
                if let newValue, let placeChatResult = modelController.placeChatResult(for: newValue) {
                    preferredCompactColumn = .detail
                    columnVisibility = .detailOnly
                    Task {
                        do {
                            try await chatModel.didTap(placeChatResult: placeChatResult, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                } else {
                    preferredCompactColumn = .content
                    if horizontalSizeClass == .compact {
                        columnVisibility = .automatic
                    } else {
                        columnVisibility = .all
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
                    let (caption, selectedDestinationID): (String, LocationResult.ID?) = await MainActor.run {
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
                        
                        try await chatModel.didSearch(
                            caption: caption,
                            selectedDestinationChatResultID: selectedDestinationID,
                            filters: searchSavedViewModel.filters,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                    } catch is CancellationError {
                        // Swallow cancellations silently
                    } catch {
                        await MainActor.run {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
            }
            .onChange(of: modelController.section) { oldValue, newValue in
                // Reset navigation when switching tabs
                placesPath = NavigationPath()
                lastPushedPlaceID = nil
                preferredCompactColumn = .sidebar
                columnVisibility = .all
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
            .pickerStyle(.segmented)
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
            Button("Settings", systemImage: "person.crop.circle") {
                showSettings.toggle()
            }
            .labelStyle(.iconOnly)
            Button {
                if !showNavigationLocationView {
                    showNavigationLocationView = true
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease")
            }
            .disabled(showNavigationLocationView)
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
            NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn) {
                switch searchMode {
                case .favorites:
                    SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, searchMode:$searchMode, columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn)
                        .navigationTitle("Favorites")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .industries:
                    SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection, section:$modelController.section)
                        .navigationTitle("Industries")
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .features:
                    SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection,  section:$modelController.section)
                        .navigationTitle("Features")
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                case .places:
                    SearchPlacesView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, multiSelection: $multiSelection, placeDirectionsChatViewModel: placeDirectionsChatViewModel)
                        .navigationTitle("Places")
                        .toolbar {
                            unifiedBrowseToolbar()
                        }
                }
            } content:{
                PlacesList(
                    searchSavedViewModel: $searchSavedViewModel,
                    chatModel: $chatModel,
                    cacheManager: $cacheManager,
                    modelController: $modelController
                )
            } detail: {
                PlaceView(
                    searchSavedViewModel: $searchSavedViewModel,
                    chatModel: $chatModel,
                    cacheManager: $cacheManager,
                    modelController: $modelController,
                    placeDirectionsViewModel: placeDirectionsChatViewModel
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

