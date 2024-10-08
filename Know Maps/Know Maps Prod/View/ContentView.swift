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
    case places
    case add
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @EnvironmentObject public var settingsModel:AppleAuthenticationService
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var searchSavedViewModel:SearchSavedViewModel
    
    @Binding public var showOnboarding:Bool
    
    @State private var selectedItem: String?
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var preferredColumn =
    NavigationSplitViewColumn.sidebar
    @State private var addItemSection: Int = 0
    @State private var settingsPresented:Bool = false
    @State private var didError = false
    @State private var contentViewDetail:ContentDetailView = .places
    
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showPlaceViewSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    
    var body: some View {
        GeometryReader() { geometry in
            NavigationSplitView(preferredCompactColumn: $preferredColumn) {
                SearchView(chatModel: chatModel, searchSavedViewModel: searchSavedViewModel, preferredColumn: $preferredColumn, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, settingsPresented: $settingsPresented, showPlaceViewSheet: $showPlaceViewSheet, didError: $didError)
#if os(iOS) || os(visionOS)
                    .sheet(isPresented: $settingsPresented) {
                        SettingsView(chatModel: chatModel, showOnboarding: $showOnboarding)
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
                    .onAppear {
                        contentViewDetail = .places
                        preferredColumn = .sidebar
                    }
#endif
                
            } detail: {
                switch contentViewDetail {
                case .places:
                    PlacesList(chatModel: chatModel, resultId: $chatModel.modelController.selectedPlaceChatResult, showMapsResultViewSheet: $showMapsResultViewSheet)
                        .alert("Unknown Place", isPresented: $didError) {
                            Button(action: {
                                chatModel.modelController.selectedPlaceChatResult = nil
                                chatModel.modelController.isFetchingResults = false
                            }, label: {
                                Text("Go Back")
                            })
                        } message: {
                            Text("We don't know much about this place.")
                        }
                        .onDisappear {
                            chatModel.resetPlaceModel()
                            chatModel.modelController.selectedSavedResult = nil
                        }
                        .toolbar {
                            if contentViewDetail == .places {
                                
                                ToolbarItem {
                                    Button {
                                        showMapsResultViewSheet.toggle()
                                    } label: {
                                        Label("Show Map", systemImage: "map")
                                    }
                                }
                            }
                            
                        }
                    
                        .sheet(isPresented: $showMapsResultViewSheet) {
                            MapResultsView( model: chatModel,  selectedMapItem: $selectedItem, cameraPosition:$cameraPosition)
                                .onChange(of: selectedItem) { oldValue, newValue in
                                    if let newValue, let placeResponse = chatModel.modelController.filteredPlaceResults.first(where: { $0.placeResponse?.fsqID == newValue }) {
                                        chatModel.modelController.selectedPlaceChatResult = placeResponse.id
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
                            PlaceView( chatModel: chatModel,  placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $chatModel.modelController.selectedPlaceChatResult)
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
                case .add:
                        AddPromptView(
                            chatModel: chatModel,
                            addItemSection: $addItemSection, contentViewDetail: $contentViewDetail
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .automatic) {
                                AddPromptToolbarView( viewModel: searchSavedViewModel,
                                                      addItemSection: $addItemSection,
                                                      contentViewDetail: $contentViewDetail, preferredColumn: $preferredColumn
                                )
                            }
                        }
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
        .onAppear(perform: {
            chatModel.modelController.analyticsManager.track(event:"ContentView",properties: nil )
        })
        .onChange(of: selectedItem, { oldValue, newValue in
            Task {
                do {
                    try await chatModel.didTapMarker(with: newValue)
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        })
    }
}

