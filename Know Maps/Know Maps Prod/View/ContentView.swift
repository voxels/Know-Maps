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
    
    @Binding var settingsModel:AppleAuthenticationService
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    
    @Binding  public var showOnboarding:Bool
    
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var addItemSection: Int = 0
    @State private var selectedCategoryID:CategoryResult.ID?
    @State public var multiSelection = Set<UUID>()
    @State private var settingsPresented:Bool = false
    @State private var didError = false
    @State private var preferredColumn:NavigationSplitViewColumn = .sidebar
    
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showPlaceViewSheet:Bool = false
    @State private var showFiltersSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedMapItem:String?
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    
    var body: some View {
        GeometryReader() { geometry in
            TabView(selection: $addItemSection) {
                NavigationSplitView {
                    SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, preferredColumn: $preferredColumn,  addItemSection: $addItemSection, settingsPresented: $settingsPresented, showPlaceViewSheet: $showPlaceViewSheet, showMapsResultViewSheet: $showMapsResultViewSheet, didError: $didError)
                        .sheet(isPresented: $settingsPresented) {
                            SettingsView(model: $settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding, settingsPresented: $settingsPresented)
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                                .presentationCompactAdaptation(.sheet)
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
                        PlacesList(searchSavedViewModel:$searchSavedViewModel,chatModel: $chatModel, cacheManager:$cacheManager, modelController: $modelController, showMapsResultViewSheet: $showMapsResultViewSheet)
                            .alert("Unknown Place", isPresented: $didError) {
                                Button(action: {
                                    DispatchQueue.main.async {
                                        modelController.selectedPlaceChatResult = nil
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
                                        Button {
                                            showFiltersSheet.toggle()
                                        } label: {
                                            Label("Show Filters", systemImage: "line.3.horizontal.decrease")
                                        }
                                        Button {
                                            if !showPlaceViewSheet {
                                                showMapsResultViewSheet.toggle()
                                            }
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
                                MapResultsView(model: $chatModel, modelController: $modelController, selectedMapItem: $selectedMapItem, cameraPosition:$cameraPosition, showMapsResultViewSheet: $showMapsResultViewSheet, showPlaceViewSheet: $showPlaceViewSheet)
                                    .onChange(of: selectedMapItem) { _,newValue in
                                        if let newValue = newValue, let placeChatResult = modelController.placeChatResult(with: newValue) {
                                            showMapsResultViewSheet.toggle()
                                            modelController.selectedPlaceChatResult = placeChatResult.id
                                        }
                                    }

                                    .frame(minHeight: geometry.size.height - 60, maxHeight: .infinity)
                                    .presentationDetents([.large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCompactAdaptation(.sheet)
                                
                            }
                            .sheet(isPresented: $showPlaceViewSheet, content: {
                                PlaceView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, placeDirectionsViewModel: placeDirectionsChatViewModel, showPlaceViewSheet: $showPlaceViewSheet)
                                    .frame(minHeight: geometry.size.height - 60, maxHeight: .infinity)
                                    .presentationDetents([.large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCompactAdaptation(.sheet)
                            })
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .tag (0)
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                NavigationSplitView {
                    SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection: $multiSelection, addItemSection: $addItemSection)
                    
                } detail: {
                    AddCategoryView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, preferredColumn: $preferredColumn, multiSelection:$multiSelection)
                }
                .navigationSplitViewStyle(.balanced)
                .tag(1)
                .tabItem {
                    Label("Types", systemImage: "building.2")
                }
                
                NavigationSplitView {
                    SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection: $multiSelection, addItemSection: $addItemSection)
                } detail: {
                    AddTasteView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection:$multiSelection, preferredColumn: $preferredColumn)
                }
                .navigationSplitViewStyle(.balanced)
                .tag(2)
                .tabItem {
                    Label("Items", systemImage: "checklist")
                }
                NavigationSplitView {
                    SearchPlacesView(chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController, addItemSection: $addItemSection)
                    
                } detail: {
                    AddPlaceView()
                }
                .navigationSplitViewStyle(.balanced)
                .tag(3)
                .tabItem {
                    Label("Places", systemImage: "mappin")
                }
            }
            .tabViewStyle(.tabBarOnly)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        preferredColumn = .sidebar
                    }) {
                        Label("List", systemImage: "list.bullet")
                            
                    }
                    AddPromptToolbarView(viewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController,
                                         addItemSection: $addItemSection,
                                         multiSelection: $multiSelection,
                                         preferredColumn: $preferredColumn
                    )
                }
            }
        }
        .onAppear(perform: {
            modelController.analyticsManager.track(event:"ContentView",properties: nil )
        })
    }
}

