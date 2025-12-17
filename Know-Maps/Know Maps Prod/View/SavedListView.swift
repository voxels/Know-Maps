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
        Text("Add some features to your list to unlock the moods section.")
    }


    var image: Image? {
        Image(systemName: "checklist")
    }
}


struct SavedListView: View {
    @Environment(\.dismiss) var dismiss

    var searchSavedViewModel: SearchSavedViewModel
    var cacheManager: CloudCacheManager
    var modelController: DefaultModelController
    @Binding public var section: Int
    @Binding public var searchMode:SearchMode

    // State variables to manage expanded/collapsed sections
    @AppStorage("isMoodsExpanded") private var isMoodsExpanded = true
    @AppStorage("isPlacesExpanded") private var isPlacesExpanded = true
    @AppStorage("isTypesExpanded") private var isTypesExpanded = true
    @AppStorage("isItemsExpanded") private var isItemsExpanded = true
    
    @State private var searchText:String = ""
    
    @State private var lastTapCategoryID: CategoryResult.ID? = nil
    @State private var lastTapAt: Date = .distantPast
    @State private var refreshError: Error?
    @State private var selectedCategoryID: CategoryResult.ID? = nil
    
    // MARK: - Computed Properties for Filtering
    
    private var filteredMoods: [CategoryResult] {
        guard !searchText.isEmpty else { return cacheManager.cachedDefaultResults }
        let needle = searchText
        return cacheManager.cachedDefaultResults.filter { result in
            let parent = result.parentCategory
            return parent.localizedCaseInsensitiveContains(needle)
        }
    }
    
    private var filteredIndustries: [CategoryResult] {
        guard !searchText.isEmpty else { return cacheManager.cachedIndustryResults }
        let needle = searchText
        return cacheManager.cachedIndustryResults.filter { result in
            let parent = result.parentCategory
            return parent.localizedCaseInsensitiveContains(needle)
        }
    }
    
    private var filteredTastes: [CategoryResult] {
        guard !searchText.isEmpty else { return cacheManager.cachedTasteResults }
        let needle = searchText
        return cacheManager.cachedTasteResults.filter { result in
            let parent = result.parentCategory
            return parent.localizedCaseInsensitiveContains(needle)
        }
    }
    
    private var filteredPlaces: [CategoryResult] {
        guard !searchText.isEmpty else { return cacheManager.cachedPlaceResults }
        let needle = searchText
        return cacheManager.cachedPlaceResults.filter { result in
            let parent = result.parentCategory
            return parent.localizedCaseInsensitiveContains(needle)
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let selectionBinding: Binding<CategoryResult.ID?> = Binding(
                    get: { selectedCategoryID },
                    set: { selectedCategoryID = $0 }
                )
                List(selection: selectionBinding) {
#if !os(macOS)
                    TipView(MenuNavigationIconTip())
#endif
                    if !cacheManager.allCachedResults.isEmpty {
#if !os(macOS)
                        Section() {
//                            SiriTipView(intent: ShowMoodResultsIntent())
                        } header: {
                            Text("Shortcuts")
                                .font(.subheadline)
                        }
#endif // !os(macOS)
                        
                        DisclosureGroup("Moods", isExpanded: $isMoodsExpanded) {
                            ForEach(filteredMoods, id: \.id) { parent in
                                Text(parent.parentCategory)
                                    .id(parent.id)
                            }
                        }
                    } else {
                        TipView(AddItemTip())
                    }
                    
                    DisclosureGroup("Favorite Industries", isExpanded: $isTypesExpanded) {
                        if !cacheManager.cachedIndustryResults.isEmpty {
                            IndustriesList(
                                items: filteredIndustries,
                                onEdit: { parent in
                                    searchSavedViewModel.editingRecommendationWeightResult = parent
                                },
                                onDelete: { indexSet in
                                    let idsToDelete = indexSet.map { cacheManager.cachedIndustryResults[$0].id }
                                    deleteCategoryItem(at: idsToDelete)
                                }
                            )
                        }
                        Button(action: {
                            searchMode = .industries
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add a industry")
                                Spacer()
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    DisclosureGroup("Favorite Features", isExpanded: $isItemsExpanded) {
                        if !cacheManager.cachedTasteResults.isEmpty {
                            TastesList(
                                items: filteredTastes,
                                onEdit: { parent in
                                    searchSavedViewModel.editingRecommendationWeightResult = parent
                                },
                                onDelete: { indexSet in
                                    let idsToDelete = indexSet.map { cacheManager.cachedTasteResults[$0].id }
                                    deleteTasteItem(at: idsToDelete)
                                }
                            )
                        }
                        Button(action: {
                            searchMode = .features
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add a feature")
                                Spacer()
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    DisclosureGroup("Favorite Places", isExpanded: $isPlacesExpanded) {
                        if !cacheManager.cachedPlaceResults.isEmpty {
                            PlacesList(
                                items: filteredPlaces,
                                onDelete: { indexSet in
                                    let idsToDelete = indexSet.map { cacheManager.cachedPlaceResults[$0].id }
                                    deletePlaceItem(at: idsToDelete)
                                }
                            )
                        }
                        Button(action: {
                            searchMode = .places
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
                .listRowBackground(Color(.systemGroupedBackground))
#endif
                .alert("Refresh Failed", isPresented: .constant(refreshError != nil), actions: {
                    Button("OK") { refreshError = nil }
                }, message: {
                    Text(refreshError?.localizedDescription ?? "An unknown error occurred. Please check your network connection and try again.")
                })
                .refreshable {
                    Task(priority: .userInitiated) {
                        do {
                            try await cacheManager.refreshCache()
                            // Update result indexer after cache refresh
                            await MainActor.run { updateResultIndex() }
                        } catch {
                            refreshError = error
                        }
                    }
                }
#if os(macOS)
                .searchable(text: $searchText, prompt: "Search for a favoriate")
#else
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a favorite")
#endif
                .onChange(of: selectedCategoryID) { (_: CategoryResult.ID?, newValue: CategoryResult.ID?) in
                    modelController.selectedCategoryChatResult = newValue
                }
                .task {
                    self.selectedCategoryID = (modelController.selectedCategoryChatResult as CategoryResult.ID?)
                    Task(priority: .high) {
                        do {
                            try await cacheManager.refreshCache()
                            // Update result indexer after cache refresh
                            await MainActor.run { updateResultIndex() }
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
            }
        }
    }
    
    private struct IndustriesList: View {
        let items: [CategoryResult]
        let onEdit: (CategoryResult) -> Void
        let onDelete: (IndexSet) -> Void

        var body: some View {
            ForEach(items, id: \.id) { parent in
                HStack {
                    Text(parent.parentCategory)
                    Spacer()
                    RatingButton(result: parent, rating: Int(parent.rating)) {
                        onEdit(parent)
                    }
                }
                .frame(maxWidth: .infinity)
                .id(parent.id)
            }
            .onDelete(perform: onDelete)
        }
    }

    private struct TastesList: View {
        let items: [CategoryResult]
        let onEdit: (CategoryResult) -> Void
        let onDelete: (IndexSet) -> Void

        var body: some View {
            ForEach(items, id: \.id) { parent in
                HStack {
                    Text(parent.parentCategory)
                    Spacer()
                    RatingButton(result: parent, rating: Int(parent.rating)) {
                        onEdit(parent)
                    }
                }
                .frame(maxWidth: .infinity)
                .id(parent.id)
            }
            .onDelete(perform: onDelete)
        }
    }

    private struct PlacesList: View {
        let items: [CategoryResult]
        let onDelete: (IndexSet) -> Void

        var body: some View {
            ForEach(items, id: \.id) { parent in
                Text(parent.parentCategory)
                    .id(parent.id)
            }
            .onDelete(perform: onDelete)
        }
    }

    private func updateResultIndex() {
        modelController.resultIndexer.updateIndex(
            placeResults: modelController.placeResults,
            recommendedPlaceResults: modelController.recommendedPlaceResults,
            relatedPlaceResults: modelController.relatedPlaceResults,
            industryResults: modelController.industryResults,
            tasteResults: modelController.tasteResults,
            cachedIndustryResults: cacheManager.cachedIndustryResults,
            cachedPlaceResults: cacheManager.cachedPlaceResults,
            cachedTasteResults: cacheManager.cachedTasteResults,
            cachedDefaultResults: cacheManager.cachedDefaultResults,
            cachedRecommendationData: cacheManager.cachedRecommendationData
        )
    }
    
    // MARK: - Helper Views
    
    private func shouldAllowSelection(for id: CategoryResult.ID) -> Bool {
        let now = Date()
        let debounce: TimeInterval = 0.2
        defer { lastTapCategoryID = id; lastTapAt = now }
        if lastTapCategoryID == id, now.timeIntervalSince(lastTapAt) < debounce {
            return false
        }
        return true
    }
    
    func deleteTasteItem(at idsToDelete: [String]) {
        Task(priority: .userInitiated) {
            let identities = idsToDelete.compactMap { modelController.cachedTasteResult(for: $0)?.parentCategory }
            guard !identities.isEmpty else { return }
            // This assumes removeCachedResults can handle multiple identities.
            // If not, the method in the ViewModel should be updated to loop.
            await searchSavedViewModel.removeCachedResults(group: "Taste", identities: identities, cacheManager: cacheManager, modelController: modelController)
        }
    }
    
    func deleteCategoryItem(at idsToDelete: [String]) {
        Task(priority: .userInitiated) {
            let identities = idsToDelete.compactMap { modelController.cachedIndustryResult(for: $0)?.parentCategory }
            guard !identities.isEmpty else { return }
            await searchSavedViewModel.removeCachedResults(group: "Category", identities: identities, cacheManager: cacheManager, modelController: modelController)
        }
    }
    
    func deletePlaceItem(at idsToDelete: [String]) {
        Task(priority: .userInitiated) {
            let fsqIDs = idsToDelete.compactMap {
                modelController.cachedPlaceResult(for: $0)?.categoricalChatResults.first?.placeResponse?.fsqID
            }
            guard !fsqIDs.isEmpty else { return }
            await searchSavedViewModel.removeCachedResults(group: "Place", identities: fsqIDs, cacheManager: cacheManager, modelController: modelController)
            // Also batch the recommendation data deletion
            for id in fsqIDs {
                try? await cacheManager.cloudCacheService.deleteRecommendationData(for: id)
            }
        }
    }
}

