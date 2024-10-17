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
    @State public var multiSelection = Set<UUID>()
    @State private var settingsPresented:Bool = false
    @State private var didError = false
    @State private var preferredColumn:NavigationSplitViewColumn = .sidebar
    
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showContentPlaceViewSheet:Bool = false
    @State private var showFiltersSheet:Bool = false
    @State private var showNavigationLocationSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedMapItem:String?
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    
    var body: some View {
            TabView(selection: $modelController.addItemSection) {
                NavigationSplitView {
                    SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, preferredColumn: $preferredColumn,  addItemSection: $modelController.addItemSection, settingsPresented: $settingsPresented, showMapsResultViewSheet: $showMapsResultViewSheet, showNavigationLocationSheet: $showNavigationLocationSheet, didError: $didError)
                        .sheet(isPresented: $settingsPresented) {
                            SettingsView(model: settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding, settingsPresented: $settingsPresented)
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                                .presentationCompactAdaptation(.sheet)
                        }
                        .task {
                            await modelController.resetPlaceModel()
                        }
                } detail: {
                    if modelController.isRefreshingPlaces {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProgressView(modelController.fetchMessage)
                                Spacer()
                            }
                            Spacer()
                        }
                    } else {
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
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .tag (0)
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                NavigationSplitView {
                    SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection)
                    
                } detail: {
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

                }
                .navigationSplitViewStyle(.balanced)
                .tag(1)
                .tabItem {
                    Label("Types", systemImage: "building.2")
                }
                
                NavigationSplitView {
                    SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection)
                } detail: {
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

                }
                .navigationSplitViewStyle(.balanced)
                .tag(2)
                .tabItem {
                    Label("Items", systemImage: "checklist")
                }
                NavigationSplitView {
                    SearchPlacesView(searchSavedViewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, multiSelection: $multiSelection, addItemSection: $modelController.addItemSection, showNavigationLocationSheet: $showNavigationLocationSheet)
                    
                } detail: {
                    if modelController.isRefreshingPlaces {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProgressView(modelController.fetchMessage)
                                Spacer()
                            }
                            Spacer()
                        }
                    } else {
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
                }
                .navigationSplitViewStyle(.balanced)
                .tag(3)
                .tabItem {
                    Label("Places", systemImage: "mappin")
                }
                
            }
            .tabViewStyle(.tabBarOnly)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: {
            modelController.analyticsManager.track(event:"ContentView",properties: nil )
        })
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
    }
    
    @ViewBuilder
    func placesList()-> some View {
        GeometryReader() { geometry in
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
                    if modelController.filteredPlaceResults.count > 0 {
                        ToolbarItemGroup {
                            if modelController.placeResults.count > 1 || modelController.recommendedPlaceResults.count > 1 {
                                Button {
                                    showFiltersSheet.toggle()
                                } label: {
                                    Label("Show Filters", systemImage: "line.3.horizontal.decrease")
                                }
                            }
                            Button {
                                showMapsResultViewSheet.toggle()
                            } label: {
                                Label("Show Map", systemImage: "map")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showFiltersSheet, content: {
                    FiltersView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, filters: $searchSavedViewModel.filters, showFiltersPopover: $showFiltersSheet)
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                    
                        .frame(minHeight: geometry.size.height, maxHeight: .infinity)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCompactAdaptation(.sheet)
                    
                }
        }
    }
}

