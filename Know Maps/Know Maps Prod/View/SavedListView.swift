//
//  SavedListView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/10/24.
//

import SwiftUI
import AppIntents

struct SavedListView: View {
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var addItemSection:Int
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var selectedResult:CategoryResult.ID?
    @State private var editingResult:CategoryResult?
    
    // State variables to manage expanded/collapsed sections
    @State private var isMoodsExpanded = true
    @State private var isPlacesExpanded = true
    @State private var isTypesExpanded = true
    @State private var isItemsExpanded = true
    
    var body: some View {
        List(selection: $selectedResult) {
            #if !os(macOS)
            Section() {
                VStack(alignment: .leading, spacing: 8) {
                    SiriTipView(intent: ShowMoodResultsIntent())
                    Text("Find a place nearby")
                    Text("Find where to go next")
                    Text("Save this place")
                    Text("Visit a new area")
                }
            } header: {
                Text("Shortcuts").font(.headline).foregroundStyle(.primary)
            }
            #endif
            DisclosureGroup(isExpanded: $isMoodsExpanded) {
                ForEach(cacheManager.cachedDefaultResults, id:\.id) {
                    parent in
                    Text(parent.parentCategory)
                }
            } label: {
                Text("Moods").font(.headline)
            }
            
            DisclosureGroup(isExpanded: $isPlacesExpanded) {
                if !cacheManager.cachedPlaceResults.isEmpty {
                    ForEach(cacheManager.cachedPlaceResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            cacheManager.cachedPlaceResults[index].id
                        }
                        deletePlaceItem(at: idsToDelete)
                    }
                }
                Text("Add a place")
                .onTapGesture {
                    addItemSection = 2
                    contentViewDetail = .add
                    preferredColumn = .detail
                }
                .foregroundStyle(.accent)
            } label: {
                Text("Places").font(.headline)
            }
            
            DisclosureGroup(isExpanded: $isTypesExpanded) {
                if !cacheManager.cachedIndustryResults.isEmpty {
                    ForEach(cacheManager.cachedIndustryResults, id:\.id) { parent in
                        HStack {
                            Text(parent.parentCategory)
                            Spacer()
                            if parent.rating <= 0 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Never", systemImage: "circle.slash")
                                        .foregroundStyle(.red)
                                        .labelStyle(.iconOnly)
                                })                                .buttonStyle(.borderless)

                            } else if parent.rating > 0 && parent.rating < 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Occasionally", systemImage: "circle")
                                        .foregroundStyle(.accent)
                                        .labelStyle(.iconOnly)
                                })
                                .buttonStyle(.borderless)
                            } else if parent.rating >= 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Often", systemImage: "circle.fill")
                                        .foregroundStyle(.green)
                                        .labelStyle(.iconOnly)
                                })                                .buttonStyle(.borderless)

                            }
                        }
                    }.onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            cacheManager.cachedIndustryResults[index].id
                        }
                        deleteCategoryItem(at: idsToDelete)
                    }
                }
                
                Text("Add a type")
                    .onTapGesture {
                        addItemSection = 0
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
                    .foregroundStyle(.accent)
                
            } label: {
                Text("Types").font(.headline)
            }
            
            DisclosureGroup(isExpanded: $isItemsExpanded) {
                if !cacheManager.cachedTasteResults.isEmpty {
                    ForEach(cacheManager.cachedTasteResults, id:\.id) { parent in
                        HStack {
                            Text(parent.parentCategory)
                            Spacer()
                            if parent.rating <= 0 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Never", systemImage: "circle.slash")
                                        .foregroundStyle(.red)
                                        .labelStyle(.iconOnly)
                                })                                .buttonStyle(.borderless)

                            } else if parent.rating > 0 && parent.rating < 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Occasionally", systemImage: "circle")
                                        .foregroundStyle(.accent)
                                        .labelStyle(.iconOnly)
                                })                                .buttonStyle(.borderless)

                            } else if parent.rating >= 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Often", systemImage: "circle.fill")
                                        .foregroundStyle(.green)
                                        .labelStyle(.iconOnly)
                                })                                .buttonStyle(.borderless)

                            }
                        }
                    }
                    .onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            cacheManager.cachedTasteResults[index].id
                        }
                        deleteTasteItem(at: idsToDelete)
                    }
                }
                Text("Add an item")
                    .onTapGesture {
                        addItemSection = 1
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
                    .foregroundStyle(.accent)
            } label: {
                Text("Items").font(.headline)
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            Task(priority:.userInitiated) {
                await cacheManager.refreshCachedResults()
            }
        }
        .sheet(item: $editingResult, content: { selectedResult in
            VStack {
                Text("\(selectedResult.parentCategory)")
                    .font(.headline)
                Button(action: {
                    Task(priority:.userInitiated) {
                        do {
                            try await viewModel.changeRating(rating: 0, for: selectedResult.identity, cacheManager: cacheManager, modelController: modelController)
                            await cacheManager.refreshCachedTastes()
                            await cacheManager.refreshCachedCategories()
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Recommend rarely", systemImage: "circle.slash")
                        .foregroundStyle(.red)
                }).padding()
                Button(action: {
                    Task(priority:.userInitiated) {
                        do {
                            try await viewModel.changeRating(rating: 2, for: selectedResult.identity, cacheManager: cacheManager, modelController: modelController)
                            await cacheManager.refreshCachedTastes()
                            await cacheManager.refreshCachedCategories()
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Recommend occasionally", systemImage: "circle")
                        .foregroundStyle(.accent)
                }).padding()
                Button(action: {
                    Task(priority:.userInitiated) {
                        do {
                            try await viewModel.changeRating(rating: 3, for: selectedResult.identity, cacheManager: cacheManager, modelController: modelController)
                            await cacheManager.refreshCachedTastes()
                            await cacheManager.refreshCachedCategories()
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Recommend often", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                }).padding()
            }.padding()
        })
        .presentationCompactAdaptation(.sheet)
    }
    
    func removeSelectedItem() async throws {
        if let selectedSavedResult = modelController.selectedSavedResult, let selectedTasteItem = modelController.cachedTasteResult(for: selectedSavedResult, cacheManager: cacheManager) {
            let idsToDelete: [UUID] = [selectedTasteItem.id]
            deleteTasteItem(at: idsToDelete)
        } else if let selectedSavedResult = modelController.selectedSavedResult, let selectedCategoryItem = modelController.cachedCategoricalResult(for: selectedSavedResult, cacheManager: cacheManager){
            let idsToDelete: [UUID] = [selectedCategoryItem.id]
            deleteCategoryItem(at: idsToDelete)
        } else if let selectedSavedResult = modelController.selectedSavedResult, let selectedPlaceItem = modelController.cachedPlaceResult(for: selectedSavedResult, cacheManager: cacheManager) {
            let idsToDelete: [UUID] = [selectedPlaceItem.id]
            deletePlaceItem(at: idsToDelete)
        }
    }
    
    func deleteTasteItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task(priority:.userInitiated){
                if let parent = modelController.cachedTasteResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    
    func deleteCategoryItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task(priority:.userInitiated){
                if let parent = modelController.cachedCategoricalResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Category", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete:[UUID]) {
        for id in idsToDelete {
            Task(priority:.userInitiated){
                if let parent = modelController.cachedPlaceResult(for: id, cacheManager: cacheManager), let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await viewModel.removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController:modelController)
                    _ = try await cacheManager.cloudCache.deleteRecommendationData(for: fsqID)
                }
            }
        }
    }
}

struct SavedListToolbarView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding  public var settingsPresented: Bool
    @Binding  public var contentViewDetail:ContentDetailView
    @Binding  public var preferredColumn:NavigationSplitViewColumn
    @Binding  public var showNavigationLocationSheet:Bool
    
    var body: some View {
        Button(action: {
            contentViewDetail = .add
            preferredColumn = .detail
        }) {
            Label("Add Prompt", systemImage: "plus.circle")
        }
        
        if let savedResult = modelController.selectedSavedResult  {
            Button(action: {
                Task(priority:.userInitiated) {
                    do {
                        try await viewModel.removeSelectedItem(selectedSavedResult: savedResult, cacheManager: cacheManager, modelController: modelController)
                    } catch {
                        modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                    }
                }
            }, label: {
                Label("Delete", systemImage: "minus.circle")
            })
        }
        
        Button("Search Location", systemImage:"location.magnifyingglass") {
            showNavigationLocationSheet.toggle()
        }
        Button {
#if os(iOS) || os(visionOS)
            settingsPresented.toggle()
#else
            openWindow(id: "SettingsView")
#endif
        } label: {
            Label("Account Settings", systemImage: "gear")
        }
    }
}
