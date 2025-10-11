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
    
    @ObservedObject var settingsModel:AppleAuthenticationService
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    
    @Binding  public var showOnboarding:Bool
    
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var selectedCategoryID:CategoryResult.ID?
    @State public var lastMultiSelection = Set<UUID>()
    @State public var multiSelection = Set<UUID>()
    @State private var didError = false
    @State private var preferredColumn:NavigationSplitViewColumn = .sidebar
    
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showFiltersSheet:Bool = false
    @State private var showSettingsSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedMapItem:String?
    @State private var showNavigationLocationView:Bool = false
    @State private var showAddRecommendationView:Bool = false
    
    @State private var searchMode: SearchMode = .favorites
    @State private var navigationPath: [ChatResult.ID] = []
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "Current Location")
    
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $modelController.section) {
                browseView()
                    .tag(0)
                    .tabItem {
                        Label("Browse", systemImage: "list.bullet")
                    }
                
                SettingsView(model: settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
                    .tag(1)
                    .tabItem {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                
            }
            .containerBackground(Color(.clear), for:.navigation)
            .tabViewStyle(.sidebarAdaptable)
            .sheet(item: $searchSavedViewModel.editingRecommendationWeightResult) { selectedResult in
                recommendationWeightSheet(for: selectedResult)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCompactAdaptation(.sheet)
            }
            .onAppear(perform: {
                modelController.analyticsManager.track(event:"ContentView",properties: nil )
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
        }
    }
    
    @ToolbarContentBuilder
    func unifiedBrowseToolbar() -> some ToolbarContent {
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
            EditButton()
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
    func filterView() -> some View {
        NavigationLocationView(
            searchSavedViewModel: $searchSavedViewModel,
            chatModel: $chatModel,
            cacheManager: $cacheManager,
            modelController: $modelController,
            filters:$searchSavedViewModel.filters
        )
    }
    
    @ViewBuilder
    func filterSheet() -> some View {
        filterView()
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            .presentationCompactAdaptation(.sheet)
    }
    
    func placesList()-> some View {
        PlacesList(searchSavedViewModel:$searchSavedViewModel,chatModel: $chatModel, cacheManager:$cacheManager, modelController: $modelController, showMapsResultViewSheet: $showMapsResultViewSheet)
            .alert("Unknown Place", isPresented: $didError) {
                Button(action: {
                    DispatchQueue.main.async {
                        withAnimation {
                            modelController.selectedPlaceChatResult = nil
                        }
                    }
                }, label: {
                    Text("Go Back")
                })
            } message: {
                Text("We don't know much about this place.")
            }
    }
    
    func placesSelectionList() -> some View {
        List(selection: $modelController.selectedPlaceChatResult) {
            ForEach(modelController.filteredPlaceResults, id: \.id) { parent in
                VStack(alignment: .leading) {
                    Text(parent.title)
                        .font(.headline)
                    if let placeResponse = parent.placeResponse, !placeResponse.formattedAddress.isEmpty {
                        Text(placeResponse.formattedAddress)
                            .font(.subheadline)
                    }
                }
            }
        }
#if os(iOS) || os(visionOS)
        .listStyle(.insetGrouped)
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
                Label("Recommend rarely", systemImage: "circle.slash")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 2, cacheManager: cacheManager, modelController: modelController)
                showAddRecommendationView = false
                
            }) {
                Label("Recommend occasionally", systemImage: "circle")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 3,  cacheManager: cacheManager, modelController: modelController)
                showAddRecommendationView = false
            }) {
                Label("Recommend often", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            Spacer()
        }
    }
    
    func browseView() -> some View {
        NavigationSplitView {
            NavigationStack {
                // Sidebar with mode picker and corresponding search sidebar content
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Search Mode", selection: $searchMode) {
                        Text("Favorites").tag(SearchMode.favorites)
                        Text("Industries").tag(SearchMode.industries)
                        Text("Features").tag(SearchMode.features)
                        Text("Places").tag(SearchMode.places)
                    }
                    .pickerStyle(.segmented)
                    
                    switch searchMode {
                    case .favorites:
                        SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, preferredColumn: $preferredColumn, searchMode:$searchMode, showMapsResultViewSheet: $showMapsResultViewSheet, didError: $didError)
                            .navigationTitle("Browse")
                    case .industries:
                        SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection, section:$modelController.section)
                            .navigationTitle("Browse")
                    case .features:
                        SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection,  section:$modelController.section)
                            .navigationTitle("Browse")
                    case .places:
                        SearchPlacesView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, multiSelection: $multiSelection)
                            .navigationTitle("Browse")
                    }
                }
                .padding([.top, .horizontal])
                .navigationDestination(for: ChatResult.ID.self) { placeID in
                    // Sidebar destination to synchronize selection; actual UI is shown in detail column
                    EmptyView()
                        .onAppear {
                            if modelController.selectedPlaceChatResult != placeID {
                                modelController.selectedPlaceChatResult = placeID
                            }
                        }
                }
            }
            .toolbar { unifiedBrowseToolbar() }
            .sheet(isPresented: $showNavigationLocationView) {
                filterSheet()
            }
        } detail: {
            detailPlacesStack()
//                .toolbar {
//                    ToolbarItem{
//                        AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, section:$modelController.section, multiSelection: $multiSelection, searchMode: $searchMode)
//                    }
//                }
        }
    }
    
    @ViewBuilder
    func detailPlacesStack() -> some View {
        NavigationStack(path: $navigationPath) {
            PlacesList(
                searchSavedViewModel: $searchSavedViewModel,
                chatModel: $chatModel,
                cacheManager: $cacheManager,
                modelController: $modelController,
                showMapsResultViewSheet: $showMapsResultViewSheet
            )
            .onChange(of: modelController.selectedPlaceChatResult) { _, newID in
                if let newID {
                    // When model reconciles to a new ChatResult.ID (e.g., after reset),
                    // ensure the NavigationStack path reflects the new endpoint.
                    if navigationPath.last != newID {
                        navigationPath = [newID]
                    }
                } else {
                    // Clear the path when selection is cleared
                    if !navigationPath.isEmpty { navigationPath.removeAll() }
                }
            }
            .navigationDestination(for: ChatResult.ID.self) { placeID in
                PlaceView(
                    chatModel: $chatModel,
                    cacheManager: $cacheManager,
                    modelController: $modelController,
                    placeDirectionsViewModel: placeDirectionsChatViewModel,
                    selectedPlaceID: placeID
                )
                .onDisappear {
                    if navigationPath.isEmpty {
                        modelController.selectedPlaceChatResult = nil
                    }
                }
                .task {
                    if modelController.selectedPlaceChatResult != placeID {
                        modelController.selectedPlaceChatResult = placeID
                    }
                }
            }
        }
    }
    
    func search(intent:AssistiveChatHostService.Intent, searchText: String) {
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

