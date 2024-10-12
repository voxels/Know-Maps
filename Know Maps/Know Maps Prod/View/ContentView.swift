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
    @State private var isRefreshingPlaces:Bool = false
    @State private var didError = false
    @State private var contentViewDetail:ContentDetailView = .home
    @State private var preferredColumn:NavigationSplitViewColumn = .sidebar
    
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showPlaceViewSheet:Bool = false
    @State private var showFiltersSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedMapItem:String?
    
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    
    var body: some View {
        GeometryReader() { geometry in
            NavigationSplitView(preferredCompactColumn: $preferredColumn) {
                switch contentViewDetail {
                case .home:
                    SearchView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, preferredColumn: $preferredColumn, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, settingsPresented: $settingsPresented, showPlaceViewSheet: $showPlaceViewSheet, isRefreshingPlaces: $isRefreshingPlaces, didError: $didError)
                        .sheet(isPresented: $settingsPresented) {
                            SettingsView(model: $settingsModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                                .presentationCompactAdaptation(.sheet)
#if os(macOS)
                                .toolbar(content: {
                                    ToolbarItem {
                                        Button(action:{
                                            settingsPresented.toggle()
                                        }, label:{
                                            Label("List", systemImage: "list.bullet")
                                        })
                                    }
                                })
#elseif os(visionOS)
                                .toolbar(content: {
                                    ToolbarItem(placement:.bottomOrnament) {
                                        Button(action:{
                                            settingsPresented.toggle()
                                        }, label:{
                                            Label("List", systemImage: "list.bullet")
                                        })
                                    }
                                })
#endif
                        }
                case .add:
                    AddPromptView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController,
                                  addItemSection: $addItemSection,
                                  contentViewDetail: $contentViewDetail, multiSelection: $multiSelection
                    )
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button(action: {
                                contentViewDetail = .home
                                preferredColumn = .sidebar
                            }) {
                                Label("List", systemImage: "list.bullet")
                            }
                            AddPromptToolbarView(viewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController,
                                                 addItemSection: $addItemSection,
                                                 multiSelection: $multiSelection, contentViewDetail: $contentViewDetail,
                                                 preferredColumn: $preferredColumn
                            )
                        }
                    }
                }
            } detail: {
                switch contentViewDetail {
                case .home:
                    
                    if isRefreshingPlaces {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProgressView("Fetching results...")
                                Spacer()
                            }
                            Spacer()
                        }
                    } else {
                        PlacesList(chatModel: $chatModel, modelController: $modelController, showMapsResultViewSheet: $showMapsResultViewSheet)
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
                                if contentViewDetail == .home, modelController.filteredPlaceResults.count > 0 {
                                    ToolbarItemGroup {
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
                            .sheet(isPresented: $showFiltersSheet, content: {
                                FiltersView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, filters: $searchSavedViewModel.filters, showFiltersPopover: $showFiltersSheet)
                            })
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                            .sheet(isPresented: $showMapsResultViewSheet) {
                                MapResultsView(model: $chatModel, modelController: $modelController, selectedMapItem: $selectedMapItem, cameraPosition:$cameraPosition)
                                    .onChange(of: selectedMapItem) { _,newValue in
                                        if let newValue = newValue, let placeChatResult = modelController.placeChatResult(for: newValue) {
                                            showMapsResultViewSheet.toggle()
                                            modelController.selectedPlaceChatResult = placeChatResult.id
                                        }
                                    }
#if os(macOS)
                                    .toolbar(content: {
                                        ToolbarItem {
                                            Button(action:{
                                                showMapsResultViewSheet.toggle()
                                            }, label:{
                                                Label("List", systemImage: "list.bullet")
                                            })
                                        }
                                    })
#elseif os(visionOS)
                                    .toolbar(content: {
                                        ToolbarItem(placement:.bottomOrnament) {
                                            Button(action:{
                                                showMapsResultViewSheet.toggle()
                                            }, label:{
                                                Label("List", systemImage: "list.bullet")
                                            })
                                        }
                                    })
#endif
                                    .frame(minHeight: geometry.size.height - 60, maxHeight: .infinity)
                                    .presentationDetents([.large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCompactAdaptation(.sheet)
                                
                            }
                            .sheet(isPresented: $showPlaceViewSheet, content: {
                                PlaceView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, placeDirectionsViewModel: placeDirectionsChatViewModel)
                                
                                    .frame(minHeight: geometry.size.height - 60, maxHeight: .infinity)
                                    .presentationDetents([.large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCompactAdaptation(.sheet)
#if os(macOS)
                                    .toolbar(content: {
                                        ToolbarItem {
                                            Button(action:{
                                                showPlaceViewSheet.toggle()
                                            }, label:{
                                                Label("List", systemImage: "list.bullet")
                                            })
                                        }
                                    })
#elseif os(visionOS)
                                    .toolbar(content: {
                                        ToolbarItem(placement:.bottomOrnament) {
                                            Button(action:{
                                                showPlaceViewSheet.toggle()
                                            }, label:{
                                                Label("List", systemImage: "list.bullet")
                                            })
                                        }
                                    })
#endif
                            })
                    }
                case .add:
                    switch addItemSection {
                    case 0:
                        AddCategoryView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, preferredColumn: $preferredColumn, multiSelection:$multiSelection)
                    case 1:
                        AddTasteView(viewModel: $searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, multiSelection:$multiSelection, preferredColumn: $preferredColumn)
                    case 2:
                        AddPlaceView()
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
        .onAppear(perform: {
            modelController.analyticsManager.track(event:"ContentView",properties: nil )
        })
    }
}

