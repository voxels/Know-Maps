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

    @Binding public var searchSavedViewModel: SearchSavedViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
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
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                List(selection:$modelController.selectedCategoryChatResult) {
#if !os(macOS)
                    TipView(MenuNavigationIconTip())
#endif
                    if !cacheManager.allCachedResults.isEmpty {
#if !os(macOS)
                        Section() {
                            SiriTipView(intent: ShowMoodResultsIntent())
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
                            }
                        }
                    } else {
                        TipView(AddItemTip())
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
                                    ratingButton(for: parent, searchMode: .industries)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .onDelete { indexSet in
                                let idsToDelete = indexSet.map { cacheManager.cachedIndustryResults[$0].id }
                                deleteCategoryItem(at: idsToDelete)
                            }
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
                            ForEach(cacheManager.cachedTasteResults.filter({ result in
                                if searchText.isEmpty { return true }
                                else {
                                    return result.parentCategory.lowercased().contains(searchText.lowercased())
                                }
                            }), id: \.id) { parent in
                                HStack {
                                    Text(parent.parentCategory)
                                    Spacer()
                                    ratingButton(for: parent, searchMode: .features)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .onDelete { indexSet in
                                let idsToDelete = indexSet.map { cacheManager.cachedTasteResults[$0].id }
                                deleteTasteItem(at: idsToDelete)
                            }
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
                            ForEach(cacheManager.cachedPlaceResults.filter({ result in
                                if searchText.isEmpty { return true }
                                else {
                                    return result.parentCategory.lowercased().contains(searchText.lowercased())
                                }
                            }), id: \.id) { parent in
                                Text(parent.parentCategory)
                            }
                            .onDelete { indexSet in
                                let idsToDelete = indexSet.map { cacheManager.cachedPlaceResults[$0].id }
                                deletePlaceItem(at: idsToDelete)
                            }
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
                .refreshable {
                    Task(priority: .userInitiated) {
                        do {
                            try await cacheManager.refreshCache()
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
#if os(macOS)
                .searchable(text: $searchText, prompt: "Search for a favoriate")
#else
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a favorite")
#endif
                .task {
                    Task(priority: .high) {
                        do {
                            try await cacheManager.refreshCache()
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
            }
        }
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
    
    @ViewBuilder
    func ratingButton(for parent: CategoryResult, searchMode:SearchMode) -> some View {
        
        switch searchMode {
        case .industries:
            let isSaved = cacheManager.cachedIndustryResults.contains(where: { $0.parentCategory == parent.parentCategory })
            if isSaved, let rating = cacheManager.cachedIndustryResults.first(where: { $0.parentCategory == parent.parentCategory })?.rating {
                switch rating {
                case ..<1:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Never", systemImage: "star.slash")
                            .foregroundColor(.red)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                case 1..<3:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Occasionally", systemImage: "star.leadinghalf.filled")
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                case 3...:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Often", systemImage: "star.fill")
                            .foregroundColor(.green)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                default:
                    EmptyView()
                }
            }

        case .features:
            let isSaved = cacheManager.cachedTasteResults.contains(where: { $0.parentCategory == parent.parentCategory })
            if isSaved, let rating = cacheManager.cachedTasteResults.first(where: { $0.parentCategory == parent.parentCategory })?.rating {
                switch rating {
                case ..<1:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Never", systemImage: "star.slash")
                            .foregroundColor(.red)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                case 1..<3:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Occasionally", systemImage: "star.leadinghalf.filled")
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                case 3...:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Often", systemImage: "star.fill")
                            .foregroundColor(.green)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                default:
                    EmptyView()
                }
            } else {
                Button(action: {
                    searchSavedViewModel.editingRecommendationWeightResult = parent
                }) {
                    Label("Occasionally", systemImage: "star.leadinghalf.filled")
                        .foregroundColor(.accentColor)
                }
                .frame(width: 44, height:44)
                .buttonStyle(BorderlessButtonStyle())
                .labelStyle(.iconOnly)
            }
        case .places:
            let isSaved = cacheManager.cachedPlaceResults.contains(where: { $0.parentCategory == parent.parentCategory })
            
            if isSaved, let rating = cacheManager.cachedPlaceResults.first(where: { $0.parentCategory == parent.parentCategory })?.rating {
                switch rating {
                case ..<1:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Never", systemImage: "star.slash")
                            .foregroundColor(.red)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                case 1..<3:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Occasionally", systemImage: "star.leadinghalf.filled")
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                case 3...:
                    Button(action: {
                        searchSavedViewModel.editingRecommendationWeightResult = parent
                    }) {
                        Label("Often", systemImage: "star.fill")
                            .foregroundColor(.green)
                    }
                    .frame(width: 44, height:44)
                    .buttonStyle(BorderlessButtonStyle())
                    .labelStyle(.iconOnly)
                default:
                    EmptyView()
                }
            } else {
                Button(action: {
                    searchSavedViewModel.editingRecommendationWeightResult = parent
                }) {
                    Label("Occasionally", systemImage: "star.leadinghalf.filled")
                        .foregroundColor(.accentColor)
                }
                .frame(width: 44, height:44)
                .buttonStyle(BorderlessButtonStyle())
                .labelStyle(.iconOnly)
            }
        default:
            EmptyView()
        }
    }
    
    func deleteTasteItem(at idsToDelete: [String]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedTasteResult(for: id) {
                    await searchSavedViewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deleteCategoryItem(at idsToDelete: [String]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedIndustryResult(for: id) {
                    await searchSavedViewModel.removeCachedResults(group: "Category", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete: [String]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedPlaceResult(for: id),
                   let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await searchSavedViewModel.removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController: modelController)
                    _ = try? await cacheManager.cloudCacheService.deleteRecommendationData(for: fsqID)
                }
            }
        }
    }
}

