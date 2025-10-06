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
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "Current Location")
    
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $modelController.section) {
                favoritesView(geometry)
                .tag(0)
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                
                TabView(selection: $modelController.addItemSection) {
                    industriesView(geometry)
                    .tag(1)
                    .tabItem {
                        Label("Industries", systemImage: "building.2")
                    }
                    
                    purchasesView(geometry)
                    .tag(2)
                    .tabItem {
                        Label("Purchases", systemImage: "checklist")
                    }
                    
                    placesView(geometry)
                    .tag(3)
                    .tabItem {
                        Label("Places", systemImage: "mappin")
                    }
                }
                .tabViewStyle(.page)
                .defaultAdaptableTabBarPlacement()
                .tag(5)
                .tabItem {
                    Label("Browse", systemImage: "list.bullet")
                }
                .containerBackground(Color(.clear), for:.navigation)
                
                SettingsView(model: settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
                    .tag(4)
                    .tabItem {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                    
            }
            .tabViewStyle(.automatic)
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
            .onChange(of: modelController.selectedPlaceChatResult, { oldValue, newValue in
                
                guard let newValue else {
                    return
                }
                
                Task { @MainActor in
                    if let placeChatResult = modelController.placeChatResult(for: newValue), modelController.addItemSection == 3, placeChatResult.placeDetailsResponse == nil {
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
            .onChange(of: showAddRecommendationView) { oldValue, newValue in
            }
        }
    }
    
    func toolbarLeadingContent() -> some View {
        
#if !os(macOS)
        EditButton()
        #else
        EmptyView()
#endif
    }
    
    
    @ViewBuilder
    func toolbarTrailingContent() -> some View {
#if !os(macOS)
        Button {
            showNavigationLocationView = true
        } label: {
            Label("Filter", systemImage:"line.3.horizontal.decrease")
        }
#else
        Button {
            showNavigationLocationView = true
        } label: {
            Label("Filter", systemImage:"line.3.horizontal.decrease")
        }
#endif
    }
    
    
    func favoritesView(_ geometry:GeometryProxy) -> some View {
        NavigationSplitView {
            SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, preferredColumn: $preferredColumn,  addItemSection: $modelController.addItemSection, showMapsResultViewSheet: $showMapsResultViewSheet, didError: $didError)
                .toolbar {
                    #if os(macOS)
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarLeadingContent()
                    }
#else
                    ToolbarItemGroup(placement: .topBarLeading) {
                        toolbarLeadingContent()
                    }
                    #endif
                }
                .navigationTitle("Favorites")
                .onChange(of: modelController.isRefreshingPlaces) { oldValue, newValue in
                    showAddRecommendationView = false
                }
        } detail: {
            NavigationStack {
                NavigationLink(isActive: $showNavigationLocationView) {
                    filterView()
                } label: {
                    EmptyView()
                }
                .hidden()
                if let resultId = modelController.selectedPlaceChatResult, let _ = modelController.placeChatResult(for: resultId) {
                    PlaceView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, placeDirectionsViewModel: placeDirectionsChatViewModel, addItemSection: $modelController.addItemSection)
                } else {
                    placesList()
                        .toolbar {
#if !os(macOS)
                            ToolbarItemGroup(placement: .topBarTrailing) {
#if !os(macOS)
        Button {
            showNavigationLocationView = true
        } label: {
            Label("Filter", systemImage:"line.3.horizontal.decrease")
        }
#else
        Button {
            showNavigationLocationView = true
        } label: {
            Label("Filter", systemImage:"line.3.horizontal.decrease")
        }
#endif
                            }
#else
                            ToolbarItemGroup(placement: .primaryAction) {
#if !os(macOS)
        Button {
            showNavigationLocationView = true
        } label: {
            Label("Filter", systemImage:"line.3.horizontal.decrease")
        }
#else
        Button {
            showNavigationLocationView = true
        } label: {
            Label("Filter", systemImage:"line.3.horizontal.decrease")
        }
#endif
                            }
#endif
                        }
                        .sheet(isPresented: $showMapsResultViewSheet) {
                            MapResultsView(model: $chatModel, modelController: $modelController, selectedMapItem: $selectedMapItem, cameraPosition:$cameraPosition)
                                .onChange(of: selectedMapItem) { _,newValue in
                                    if let newValue = newValue, let placeChatResult = modelController.placeChatResult(with: newValue) {
                                        withAnimation {
                                            showMapsResultViewSheet.toggle()
                                        } completion: {
                                            Task(priority: .userInitiated) {
                                                do {
                                                    try await modelController.resetPlaceModel()
                                                    try await  chatModel.didTap(placeChatResult: placeChatResult, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                                                } catch {
                                                    modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
                                                }
                                            }
                                        }
                                    }
                                }
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                                .presentationCompactAdaptation(.sheet)
                                .frame(minWidth:geometry.size.width, maxWidth: .infinity, minHeight:geometry.size.height, maxHeight: .infinity)
                        }
                }
            }
        }
    }
    
    func industriesView(_ geometry:GeometryProxy) -> some View {
        NavigationSplitView {
            SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection, section:$modelController.section, addItemSection: $modelController.addItemSection)
                .toolbar {
#if os(macOS)
ToolbarItemGroup(placement: .primaryAction) {
toolbarLeadingContent()
}
#else
ToolbarItemGroup(placement: .topBarLeading) {
toolbarLeadingContent()
}
#endif
                }
                .navigationTitle("Industries")
        } detail: {
            NavigationStack {
                NavigationLink(isActive: $showNavigationLocationView) {
                    filterView()
                } label: {
                    EmptyView()
                }
                .hidden()
                   VStack(alignment: .leading, spacing: 0) {
                        placesList()
                    }
                    .toolbar {
#if !os(macOS)
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            toolbarTrailingContent()
                        }
#else
                        ToolbarItemGroup(placement: .primaryAction) {
                            toolbarTrailingContent()
                        }
#endif
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                 section: $modelController.section, addItemSection: $modelController.addItemSection,
                                                 multiSelection: $multiSelection,
                                                 preferredColumn: $preferredColumn
                            )
                        }
                }
            }
        }
    }
    
    func purchasesView(_ geometry:GeometryProxy) -> some View {
        NavigationSplitView {
            SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, multiSelection: $multiSelection,  section:$modelController.section,addItemSection: $modelController.addItemSection)
                .navigationTitle("Purchases")
                .toolbar {
#if os(macOS)
ToolbarItemGroup(placement: .automatic) {
toolbarLeadingContent()
}
#else
ToolbarItemGroup(placement: .topBarLeading) {
toolbarLeadingContent()
}
#endif
                }
        } detail: {
            NavigationStack {
                NavigationLink(isActive: $showNavigationLocationView) {
                    filterView()
                } label: {
                    EmptyView()
                }
                .hidden()
                    placesList()
                    .toolbar {
#if !os(macOS)
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            toolbarTrailingContent()
                        }
#else
                        ToolbarItemGroup(placement: .primaryAction) {
                            toolbarTrailingContent()
                        }
#endif
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel:$chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                 section: $modelController.section, addItemSection: $modelController.addItemSection,
                                                 multiSelection: $multiSelection,
                                                 preferredColumn: $preferredColumn
                            )
                        }
                    }
            }
        }
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
    
    func placesView(_ geometry:GeometryProxy) -> some View {
        NavigationSplitView {
            SearchPlacesView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection)
                .navigationTitle("Places")
            
        } detail: {
            NavigationStack {
                NavigationLink(isActive: $showNavigationLocationView) {
                    filterView()
                } label: {
                    EmptyView()
                }
                .hidden()
                PlaceView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, placeDirectionsViewModel: placeDirectionsChatViewModel, addItemSection: $modelController.addItemSection)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel:$chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                 section: $modelController.section, addItemSection: $modelController.addItemSection,
                                                 multiSelection: $multiSelection,
                                                 preferredColumn: $preferredColumn
                            )
                        }
#if !os(macOS)
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            toolbarTrailingContent()
                        }
#else
                        ToolbarItemGroup(placement: .primaryAction) {
                            toolbarTrailingContent()

                        }
#endif
                    }
            }
        }
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
}

