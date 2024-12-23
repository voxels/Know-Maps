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
        Text("Page Menu")
    }


    var message: Text? {
        Text("Add items, categories, and places to your favorites.")
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
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $modelController.addItemSection) {
                NavigationSplitView {
                    SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, preferredColumn: $preferredColumn,  addItemSection: $modelController.addItemSection, showMapsResultViewSheet: $showMapsResultViewSheet, didError: $didError)
                        .toolbar {
#if !os(macOS)
                            ToolbarItem(placement:.navigation) {
                                navigationToolbar()
                            }
#endif
                            ToolbarItemGroup(placement: .automatic) {
#if !os(macOS)
                                EditButton()
#endif
                                Button {
                                    showNavigationLocationView.toggle()
                                } label: {
                                    Label("Destination", systemImage:"location.magnifyingglass")
                                }
                                Button {
                                    showSettingsSheet.toggle()
                                } label: {
                                    Label("Settings", systemImage: "gearshape")
                                }
                            }
                        }
#if !os(macOS)
                        .toolbarBackground(.visible, for: .navigationBar)
#endif
                        .navigationTitle("Favorites")
                } detail: {
                    if let resultId = modelController.selectedPlaceChatResult, let _ = modelController.placeChatResult(for: resultId) {
                        PlaceView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, placeDirectionsViewModel: placeDirectionsChatViewModel, addItemSection: $modelController.addItemSection)
                            .toolbar {
                                ToolbarItemGroup(placement: .primaryAction) {
                                    AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                         addItemSection: $modelController.addItemSection,
                                                         multiSelection: $multiSelection,
                                                         preferredColumn: $preferredColumn
                                    )
                                }
                            }
                    } else {
                        placesList()
                            .sheet(isPresented: $showFiltersSheet, content: {
                                FiltersView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, filters: $searchSavedViewModel.filters, showFiltersPopover: $showFiltersSheet)
                                    .presentationDetents([.large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCompactAdaptation(.sheet)
                                    .frame(minWidth:sizeClass == .compact ? geometry.size.width : geometry.size.width / 3, maxWidth: .infinity, minHeight:geometry.size.height, maxHeight: .infinity)
                                
                                
                            })
                            .sheet(isPresented: $showMapsResultViewSheet) {
                                MapResultsView(model: $chatModel, modelController: $modelController, selectedMapItem: $selectedMapItem, cameraPosition:$cameraPosition, showMapsResultViewSheet: $showMapsResultViewSheet)
                                    .onChange(of: selectedMapItem) { _,newValue in
                                        if let newValue = newValue, let placeChatResult = modelController.placeChatResult(with: newValue) {
                                            withAnimation {
                                                showMapsResultViewSheet.toggle()
                                            } completion: {
                                                Task(priority: .userInitiated) {
                                                    do {
                                                        await modelController.resetPlaceModel()
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
                .navigationSplitViewStyle(.balanced)
                .tag (0)
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
#if !os(macOS)
                .toolbar(.hidden, for: .tabBar)
#endif
                
                NavigationSplitView {
                    SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection)
#if !os(macOS)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                navigationToolbar()
                            }
                            ToolbarItemGroup(placement: .primaryAction) {
                                EditButton()
                                Button {
                                    showNavigationLocationView.toggle()
                                } label: {
                                    Label("Destination", systemImage:"location.magnifyingglass")
                                }
                            }
                        }
                        .toolbarBackground(.visible, for: .navigationBar)
#endif
                        .navigationTitle("Types")
                    
                } detail: {
                    if sizeClass == .compact {
                        VStack {
                            AddCategoryView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, preferredColumn: $preferredColumn, multiSelection:$multiSelection)
                                .toolbar {
                                    ToolbarItemGroup(placement: .primaryAction) {
                                        AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                             addItemSection: $modelController.addItemSection,
                                                             multiSelection: $multiSelection,
                                                             preferredColumn: $preferredColumn
                                        )
                                    }
                                }
                            placesList()
                        }
                    } else {
                        HStack {
                            AddCategoryView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, preferredColumn: $preferredColumn, multiSelection:$multiSelection)
                                .toolbar {
                                    ToolbarItemGroup(placement: .primaryAction) {
                                        AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                             addItemSection: $modelController.addItemSection,
                                                             multiSelection: $multiSelection,
                                                             preferredColumn: $preferredColumn
                                        )
                                    }
                                }.frame(maxWidth:sizeClass == .compact ? geometry.size.width : geometry.size.width / 4)
                            placesList()
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .tag(1)
                .tabItem {
                    Label("Types", systemImage: "building.2")
                }
#if !os(macOS)
                .toolbar(.hidden, for: .tabBar)
#endif
                
                NavigationSplitView {
                    SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection)
#if !os(macOS)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                navigationToolbar()
                            }
                            ToolbarItemGroup(placement: .primaryAction) {
                                EditButton()
                                Button {
                                    showNavigationLocationView.toggle()
                                } label: {
                                    Label("Destination", systemImage:"location.magnifyingglass")
                                }
                            }
                        }
                        .toolbarBackground(.visible, for: .navigationBar)
#endif
                        .navigationTitle("Items")
                } detail: {
                    if sizeClass == .compact {
                        VStack {
                            AddTasteView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection:$multiSelection, preferredColumn: $preferredColumn)
                                .toolbar {
                                    ToolbarItemGroup(placement: .primaryAction) {
                                        AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel:$chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                             addItemSection: $modelController.addItemSection,
                                                             multiSelection: $multiSelection,
                                                             preferredColumn: $preferredColumn
                                        )
                                    }
                                }
                            placesList()
                        }
                    } else {
                        HStack {
                            AddTasteView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection:$multiSelection, preferredColumn: $preferredColumn)
                                .toolbar {
                                    ToolbarItemGroup(placement: .primaryAction) {
                                        AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel:$chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                             addItemSection: $modelController.addItemSection,
                                                             multiSelection: $multiSelection,
                                                             preferredColumn: $preferredColumn
                                        )
                                    }
                                }
                                .frame(maxWidth:sizeClass == .compact ? geometry.size.width : geometry.size.width / 4)
                            placesList()
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .tag(2)
                .tabItem {
                    Label("Items", systemImage: "checklist")
                }
#if !os(macOS)
                .toolbar(.hidden, for: .tabBar)
#endif
                NavigationSplitView {
                    SearchPlacesView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection)
                        .toolbar {
#if !os(macOS)
                            ToolbarItem(placement: .navigation) {
                                navigationToolbar()
                            }
#endif
                            ToolbarItem(placement: .automatic) {
                                Button {
                                    showNavigationLocationView.toggle()
                                } label: {
                                    Label("Destination", systemImage:"location.magnifyingglass")
                                }
                            }
                        }
#if !os(macOS)
                        .toolbarBackground(.visible, for: .navigationBar)
#endif
                        .navigationTitle("Places")
                    
                } detail: {
                    PlaceView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, placeDirectionsViewModel: placeDirectionsChatViewModel, addItemSection: $modelController.addItemSection)
                        .toolbar {
                            ToolbarItemGroup(placement: .primaryAction) {
                                AddPromptToolbarView(viewModel: $searchSavedViewModel, chatModel:$chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                                     addItemSection: $modelController.addItemSection,
                                                     multiSelection: $multiSelection,
                                                     preferredColumn: $preferredColumn
                                )
                            }
                            
                        }
                }
                .navigationSplitViewStyle(.balanced)
                .tag(3)
                .tabItem {
                    Label("Places", systemImage: "mappin")
                }
#if !os(macOS)
                .toolbar(.hidden, for: .tabBar)
#endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: {
                modelController.analyticsManager.track(event:"ContentView",properties: nil )
            })
            .onChange(of: modelController.selectedDestinationLocationChatResult, { oldValue, newValue in
                if newValue != nil {
                    modelController.selectedSavedResult = nil
                    Task(priority:.userInitiated) {
                        await modelController.resetPlaceModel()
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
                    await modelController.resetPlaceModel()
                    do {
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
                
                guard let newValue, newValue != oldValue else {
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
            .sheet(isPresented: $showNavigationLocationView) {
                NavigationLocationView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showNavigationLocationView: $showNavigationLocationView)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCompactAdaptation(.sheet)
                    .frame(minWidth:sizeClass == .compact ? geometry.size.width : geometry.size.width / 3, maxWidth: .infinity, minHeight:geometry.size.height, maxHeight: .infinity)
            }
            .sheet(isPresented:$showSettingsSheet) {
                SettingsView(model: settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCompactAdaptation(.sheet)
                    .frame(minWidth:sizeClass == .compact ? geometry.size.width : geometry.size.width / 3, maxWidth: .infinity, minHeight:geometry.size.height, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    func navigationToolbar() -> some View {
        Picker("Add to Favories", systemImage: "plus.circle", selection: $modelController.addItemSection) {
            Label("Favorites", systemImage: "heart.fill").tag(0)
            Label("Add a type", systemImage: "building.2").tag(1)
            Label("Add an item", systemImage: "checklist").tag(2)
            Label("Add a place", systemImage: "mappin").tag(3)
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    func placesList()-> some View {
        VStack {
            #if os(macOS)
            TipView(MenuNavigationIconTip())
                .padding()
            #endif
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
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            showFiltersSheet.toggle()
                        } label: {
                            Label("Show Filters", systemImage: "line.3.horizontal.decrease")
                        }
                        Button {
                            showMapsResultViewSheet.toggle()
                        } label: {
                            Label("Show Map", systemImage: "map")
                        }
                    }
                }
        }
    }
}

