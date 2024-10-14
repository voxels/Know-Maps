//
//  SearchPlacesView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/22/24.
//


import SwiftUI

struct SearchPlacesView: View {
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<UUID>
    @Binding public var addItemSection: Int
    @Binding public var showNavigationLocationSheet: Bool
    @State private var searchText: String = "" // State for search text
    
    var body: some View {
        GeometryReader { geometry in
            List(selection: $modelController.selectedPlaceChatResult) {
                if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: (modelController.filteredLocationResults(cacheManager: cacheManager))) {
                    let locationName = locationChatResult.locationName
                    Text("\(modelController.placeResults.count) places found near \(locationName)")
                } else {
                    Text("Choose a location to search for places")
                }
                // Use filtered results here
                ForEach(modelController.filteredPlaceResults, id: \.id) { parent in
                    VStack(alignment: .leading) {
                        Text(parent.title)
                            .font(.headline)
                        if let placeResponse = parent.placeResponse     {
                            Text(placeResponse.formattedAddress).font(.subheadline)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            #if os(macOS)
            .searchable(text: $searchText, prompt: "Search by place name")
            #else
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search by place name") // Add searchable
            #endif
            .onSubmit(of: .search, {
                if !searchText.isEmpty{
                    Task(priority:.userInitiated) {
                        await searchSavedViewModel.search(caption: searchText, selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult ?? modelController.currentLocationResult.id, intent: .AutocompletePlaceSearch, filters: searchSavedViewModel.filters, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController)
                    }
                }
            })
            #if !os(macOS)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        showNavigationLocationSheet.toggle()
                    }) {
                        Label("Search Location", systemImage: "location.magnifyingglass")
                    }
                    
                    
                }
            }
            .sheet(isPresented: $showNavigationLocationSheet) {
                VStack {
                    HStack {
                        TextField("City, State", text: $searchText)
                            .onSubmit {
                                search(intent:.Location)
                            }
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            search(intent:.Location)
                        }, label: {
                            Label("Search", systemImage: "magnifyingglass")
                        })
                    }
                    .padding()
                    
                    NavigationLocationView(chatModel: $chatModel, cacheManager: $cacheManager, modelController:$modelController)
                    
                    HStack {
                        Button(action:{
                            showNavigationLocationSheet.toggle()
                        }, label:{
                            Label("List", systemImage: "list.bullet")
                        }).padding()
                        Spacer()
                        if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let parent =  modelController.locationChatResult(
                            for: selectedDestinationLocationChatResult,in: modelController.filteredLocationResults(cacheManager: cacheManager)) {
                            let isSaved = cacheManager.cachedLocation(contains: parent.locationName)
                            if isSaved {
                                Button(action: {
                                    if let location = parent.location {
                                        Task(priority:.userInitiated) {
                                            await searchSavedViewModel.removeCachedResults(
                                                group: "Location",
                                                identity: cacheManager.cachedLocationIdentity(for: location),
                                                cacheManager: cacheManager,
                                                modelController: modelController
                                            )
                                        }
                                    }
                                }, label: {
                                    Label("Delete", systemImage: "minus.circle")
                                })
                                .labelStyle(.titleAndIcon)
                                .padding()
                            } else {
                                Button(action: {
                                    if let location = parent.location {
                                        Task(priority:.userInitiated) {
                                            do {
                                                try await searchSavedViewModel.addLocation(
                                                    parent: parent,
                                                    location: location,
                                                    cacheManager: cacheManager,
                                                    modelController: modelController
                                                )
                                                modelController.selectedDestinationLocationChatResult = modelController.filteredLocationResults(cacheManager:cacheManager).first(where: {$0.locationName == parent.locationName})?.id
                                            } catch {
                                                modelController.analyticsManager.trackError(
                                                    error: error,
                                                    additionalInfo: nil
                                                )
                                            }
                                        }
                                    }
                                }, label: {
                                    Label("Save", systemImage: "plus.circle")
                                })
                                .labelStyle(.titleAndIcon)
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
                .padding()
                .frame(minHeight: geometry.size.height, maxHeight: .infinity)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCompactAdaptation(.sheet)
            }
        }
    }
    
    
    func search(intent:AssistiveChatHostService.Intent) {
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
