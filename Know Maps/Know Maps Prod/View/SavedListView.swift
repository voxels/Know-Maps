//
//  SavedListView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/10/24.
//
import SwiftUI
import AppIntents
import TipKit

struct AddItemTip: Tip {
    var title: Text {
        Text("Add items")
    }


    var message: Text? {
        Text("Add a feature to your list to unlock the moods section.")
    }


    var image: Image? {
        Image(systemName: "checklist")
    }
}


struct SavedListView: View {
    @Environment(\.dismiss) var dismiss

    @Binding public var searchSavedViewModel: SearchSavedViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var addItemSection: Int
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var selectedResult: CategoryResult.ID?
    
    // State variables to manage expanded/collapsed sections
    @AppStorage("isMoodsExpanded") private var isMoodsExpanded = true
    @AppStorage("isPlacesExpanded") private var isPlacesExpanded = true
    @AppStorage("isTypesExpanded") private var isTypesExpanded = true
    @AppStorage("isItemsExpanded") private var isItemsExpanded = true
    
    @State private var searchText:String = ""
    
    var body: some View {
        GeometryReader { geometry in
            List(selection: $selectedResult) {
#if !os(macOS)
                TipView(MenuNavigationIconTip())
#endif
                if !cacheManager.cachedTasteResults.isEmpty {
#if !os(macOS)
                    Section() {
                        SiriTipView(intent: ShowMoodResultsIntent())
                    
                        //                    Text("Find a place nearby")
                        //                    Text("Find where to go next")
                        //                    Text("Save this place")
                        //                    Text("Visit a new city")
                    } header: {
                        Text("Shortcuts")
                            .font(.subheadline)
                    }
#endif // !os(macOS)
                    
                    DisclosureGroup("Moods", isExpanded: $isMoodsExpanded) {
                        ForEach(cacheManager.cachedDefaultResults.filter({ result in
                            if searchText.isEmpty { return true }
                            else {
                                return result.parentCategory.lowercased().contains(searchText.lowercased())
                            }
                        }), id: \.id) { parent in
                            Text(parent.parentCategory)
                                .padding(.vertical, 12)
                        }
                    }
                } else {
                    TipView(AddItemTip())
                }

                DisclosureGroup("Favorite Features", isExpanded: $isItemsExpanded) {
                    if !cacheManager.cachedTasteResults.isEmpty {
                        ForEach(cacheManager.cachedTasteResults.filter({ result in
                            if searchText.isEmpty { return true }
                            else {
                                return result.parentCategory.lowercased().contains(searchText.lowercased())
                            }
                        }), id: \.id) { parent in
                            HStack {
                                Text(parent.parentCategory)
                                Spacer()
                                ratingButton(for: parent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .onDelete { indexSet in
                            let idsToDelete = indexSet.map { cacheManager.cachedTasteResults[$0].id }
                            deleteTasteItem(at: idsToDelete)
                        }
                    }
                    Button(action: {
                        addItemSection = 2
                        preferredColumn = .sidebar
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add a feature")
                            Spacer()
                        }
                        
                        .foregroundColor(.accentColor)
                    }
                }
                
                DisclosureGroup("Favorite Industries", isExpanded: $isTypesExpanded) {
                    if !cacheManager.cachedIndustryResults.isEmpty {
                        ForEach(cacheManager.cachedIndustryResults.filter({ result in
                            if searchText.isEmpty { return true }
                            else {
                                return result.parentCategory.lowercased().contains(searchText.lowercased())
                            }
                        }), id: \.id) { parent in
                            HStack {
                                Text(parent.parentCategory)
                                Spacer()
                                ratingButton(for: parent)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .onDelete { indexSet in
                            let idsToDelete = indexSet.map { cacheManager.cachedIndustryResults[$0].id }
                            deleteCategoryItem(at: idsToDelete)
                        }
                    }
                    Button(action: {
                        addItemSection = 1
                        preferredColumn = .sidebar
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add a industry")
                            Spacer()
                        }
                        
                        .foregroundColor(.accentColor)
                    }
                }
                
                DisclosureGroup("Favorite Places", isExpanded: $isPlacesExpanded) {
                    if !cacheManager.cachedPlaceResults.isEmpty {
                        ForEach(cacheManager.cachedPlaceResults.filter({ result in
                            if searchText.isEmpty { return true }
                            else {
                                return result.parentCategory.lowercased().contains(searchText.lowercased())
                            }
                        }), id: \.id) { parent in
                            Text(parent.parentCategory)
                                .padding(.vertical,12)
                        }
                        .onDelete { indexSet in
                            let idsToDelete = indexSet.map { cacheManager.cachedPlaceResults[$0].id }
                            deletePlaceItem(at: idsToDelete)
                        }
                    }
                    Button(action: {
                        addItemSection = 3
                        preferredColumn = .sidebar
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add a place")
                            Spacer()
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
#if os(iOS) || os(visionOS)
            .listStyle(InsetGroupedListStyle())
#endif
            .refreshable {
                Task(priority: .userInitiated) {
                    do {
                        try await cacheManager.refreshCache()
                    } catch {
                        modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search for a favorite")
            .task {
                Task(priority: .high) {
                    await cacheManager.refreshCachedResults()
                }
            }
            .sheet(item: $searchSavedViewModel.editingRecommendationWeightResult) { selectedResult in
                recommendationWeightSheet(for: selectedResult)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCompactAdaptation(.sheet)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    func ratingButton(for parent: CategoryResult) -> some View {
        switch parent.rating {
        case ..<1:
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Never", systemImage: "circle.slash")
                    .foregroundColor(.red)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        case 1..<3:
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Occasionally", systemImage: "circle")
                    .foregroundColor(.accentColor)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        case 3:
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Often", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        default:
            EmptyView()
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
            }) {
                Label("Recommend rarely", systemImage: "circle.slash")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 2, cacheManager: cacheManager, modelController: modelController)
            }) {
                Label("Recommend occasionally", systemImage: "circle")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            
            Button(action: {
                searchSavedViewModel.updateRating(for: selectedResult, rating: 3,  cacheManager: cacheManager, modelController: modelController)
            }) {
                Label("Recommend often", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderless)
                .padding()
            
            Spacer()
        }
    }
    
    func deleteTasteItem(at idsToDelete: [UUID]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedTasteResult(for: id, cacheManager: cacheManager) {
                    await searchSavedViewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deleteCategoryItem(at idsToDelete: [UUID]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedCategoricalResult(for: id, cacheManager: cacheManager) {
                    await searchSavedViewModel.removeCachedResults(group: "Category", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete: [UUID]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedPlaceResult(for: id, cacheManager: cacheManager),
                   let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await searchSavedViewModel.removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController: modelController)
                    _ = try? await cacheManager.cloudCache.deleteRecommendationData(for: fsqID)
                }
            }
        }
    }
}
