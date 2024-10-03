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
    case order
    case add
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @EnvironmentObject public var cloudCache:CloudCache
    @EnvironmentObject public var settingsModel:SettingsModel
    @EnvironmentObject public var featureFlags:FeatureFlags
    
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    
    @Binding public var showOnboarding:Bool
    
    @State private var selectedItem: String?
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var columnVisibility =
    NavigationSplitViewVisibility.all
    @State private var preferredColumn =
    NavigationSplitViewColumn.sidebar
    @State private var sectionSelection: String = "Feature"
    @State private var settingsPresented:Bool = false
    @State private var didError = false
    @State private var contentViewDetail:ContentDetailView = .places
    
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showPlaceViewSheet:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")

    var body: some View {
        GeometryReader() { geometry in
            NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
                SearchView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, columnVisibility: $columnVisibility, preferredColumn: $preferredColumn, contentViewDetail: $contentViewDetail, settingsPresented: $settingsPresented, showPlaceViewSheet: $showPlaceViewSheet, didError: $didError)
#if os(iOS) || os(visionOS)
                    .sheet(isPresented: $settingsPresented) {
                        SettingsView(chatModel: chatModel, showOnboarding: $showOnboarding)
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                            .presentationCompactAdaptation(.sheet)
                    }
                    .onAppear {
                        contentViewDetail = .places
                        columnVisibility = .all
                    }
#endif
            } detail: {
                switch contentViewDetail {
                case .places:
                    PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult, showMapsResultViewSheet: $showMapsResultViewSheet)
                        .alert("Unknown Place", isPresented: $didError) {
                            Button(action: {
                                chatModel.selectedPlaceChatResult = nil
                                chatModel.isFetchingResults = false
                            }, label: {
                                Text("Go Back")
                            })
                        } message: {
                            Text("We don't know much about this place.")
                        }
                        .onDisappear {
                            chatModel.resetPlaceModel()
                            chatModel.selectedSavedResult = nil
                        }
                    
                    .sheet(isPresented: $showMapsResultViewSheet) {
                        MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem, cameraPosition:$cameraPosition)
                            .onChange(of: selectedItem) { oldValue, newValue in
                                if let newValue, let placeResponse = chatModel.filteredPlaceResults.first(where: { $0.placeResponse?.fsqID == newValue }) {
                                    chatModel.selectedPlaceChatResult = placeResponse.id
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
                        #endif
                            .frame(minHeight: geometry.size.height - 60, maxHeight: .infinity)
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                            .presentationCompactAdaptation(.sheet)

                    }
                    .sheet(isPresented: $showPlaceViewSheet, content: {
                        PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $chatModel.selectedPlaceChatResult)
                            .frame(minHeight: geometry.size.height - 60, maxHeight: .infinity)
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                            .presentationCompactAdaptation(.sheet)
                    })
        
                case .order:
                    PromptRankingView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, contentViewDetail: $contentViewDetail)
                case .add:
                    if sizeClass == .compact {
                        AddPromptView(
                            chatHost: chatHost,
                            chatModel: chatModel,
                            locationProvider: locationProvider,
                            sectionSelection: $sectionSelection, contentViewDetail: $contentViewDetail
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .automatic) {
                                AddPromptToolbarView(
                                    chatModel: chatModel,
                                    sectionSelection: $sectionSelection,
                                    contentViewDetail: $contentViewDetail, columnVisibility: $columnVisibility
                                )
                            }
                        }
                    } else {
                        HStack {
                            AddPromptView(
                                chatHost: chatHost,
                                chatModel: chatModel,
                                locationProvider: locationProvider,
                                sectionSelection: $sectionSelection, contentViewDetail: $contentViewDetail
                            )
                            .toolbar {
                                ToolbarItemGroup(placement: .automatic) {
                                    AddPromptToolbarView(
                                        chatModel: chatModel,
                                        sectionSelection: $sectionSelection,
                                        contentViewDetail: $contentViewDetail, columnVisibility: $columnVisibility
                                    )
                                }
                            }
                            .frame(maxWidth:geometry.size.width / 3)
                            PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult, showMapsResultViewSheet: $showMapsResultViewSheet)
                        }
                    }
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
        .onAppear(perform: {
            chatModel.analytics?.screen(title: "NavigationSplitView")
        })
        .onChange(of: selectedItem, { oldValue, newValue in
            Task {
                try await chatModel.didTapMarker(with: newValue)
            }
        })
        .onChange(of: columnVisibility) { oldValue, newValue in
            if newValue == .all {
                preferredColumn = .sidebar
                contentViewDetail = .places
            } else {
                preferredColumn = .detail
            }
        }
    }
}

