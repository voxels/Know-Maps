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
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var contentViewDetail: ContentDetailView
    @Binding public var addItemSection: Int
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var selectedResult: CategoryResult.ID?
    
    // State variables to manage expanded/collapsed sections
    @State private var isMoodsExpanded = true
    @State private var isPlacesExpanded = true
    @State private var isTypesExpanded = true
    @State private var isItemsExpanded = true
    
    var body: some View {
        List {
            #if !os(macOS)
            Section(header: Text("Shortcuts").font(.headline).foregroundStyle(.primary)) {
                VStack(alignment: .leading, spacing: 8) {
                    SiriTipView(intent: ShowMoodResultsIntent())
                    Text("Find a place nearby")
                    Text("Find where to go next")
                    Text("Save this place")
                    Text("Visit a new area")
                }
                .padding(.vertical, 4)
            }
            #endif
            
            DisclosureGroup("Moods", isExpanded: $isMoodsExpanded) {
                ForEach(cacheManager.cachedDefaultResults, id: \.id) { parent in
                    Text(parent.parentCategory)
                        .onTapGesture {
                            selectedResult = parent.id
                        }
                }
            }
        
            DisclosureGroup("Types", isExpanded: $isTypesExpanded) {
                if !cacheManager.cachedIndustryResults.isEmpty {
                    ForEach(cacheManager.cachedIndustryResults, id: \.id) { parent in
                        HStack {
                            Text(parent.parentCategory)
                                .onTapGesture {
                                    selectedResult = parent.id
                                }
                            Spacer()
                            ratingButton(for: parent)
                        }
                    }
                    .onDelete { indexSet in
                        let idsToDelete = indexSet.map { cacheManager.cachedIndustryResults[$0].id }
                        deleteCategoryItem(at: idsToDelete)
                    }
                }
                Button(action: {
                    addItemSection = 0
                    contentViewDetail = .add
                    preferredColumn = .sidebar
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add a type")
                    }
                    .foregroundColor(.accentColor)
                }
            }
            
            DisclosureGroup("Items", isExpanded: $isItemsExpanded) {
                if !cacheManager.cachedTasteResults.isEmpty {
                    ForEach(cacheManager.cachedTasteResults, id: \.id) { parent in
                        HStack {
                            Text(parent.parentCategory)
                                .onTapGesture {
                                    selectedResult = parent.id
                                }
                            Spacer()
                            ratingButton(for: parent)
                        }
                    }
                    .onDelete { indexSet in
                        let idsToDelete = indexSet.map { cacheManager.cachedTasteResults[$0].id }
                        deleteTasteItem(at: idsToDelete)
                    }
                }
                Button(action: {
                    addItemSection = 1
                    contentViewDetail = .add
                    preferredColumn = .sidebar
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add an item")
                    }
                    .foregroundColor(.accentColor)
                }
            }
            
            DisclosureGroup("Places", isExpanded: $isPlacesExpanded) {
                if !cacheManager.cachedPlaceResults.isEmpty {
                    ForEach(cacheManager.cachedPlaceResults, id: \.id) { parent in
                        Text(parent.parentCategory)
                            .onTapGesture {
                                selectedResult = parent.id
                            }
                    }
                    .onDelete { indexSet in
                        let idsToDelete = indexSet.map { cacheManager.cachedPlaceResults[$0].id }
                        deletePlaceItem(at: idsToDelete)
                    }
                }
                Button(action: {
                    addItemSection = 2
                    preferredColumn = .sidebar
                    contentViewDetail = .add
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add a place")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        #if os(iOS) || os(visionOS)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .toolbar(content: {
            EditButton()
        })
        .refreshable {
            Task(priority: .userInitiated) {
                await cacheManager.refreshCachedResults()
            }
        }
        .sheet(item: $viewModel.editingRecommendationWeightResult) { selectedResult in
            recommendationWeightSheet(for: selectedResult)
        }
        .presentationCompactAdaptation(.sheet)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    func ratingButton(for parent: CategoryResult) -> some View {
        switch parent.rating {
        case ..<1:
            Button(action: {
                viewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Never", systemImage: "circle.slash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        case 1..<3:
            Button(action: {
                viewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Occasionally", systemImage: "circle")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        default:
            Button(action: {
                viewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Often", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        }
    }
    
    @ViewBuilder
    func recommendationWeightSheet(for selectedResult: CategoryResult) -> some View {
        VStack(spacing: 20) {
            Text(selectedResult.parentCategory)
                .font(.headline)
            
            Button(action: {
                viewModel.updateRating(for: selectedResult, rating: 0, cacheManager: cacheManager, modelController: modelController)
            }) {
                Label("Recommend rarely", systemImage: "circle.slash")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Button(action: {
                viewModel.updateRating(for: selectedResult, rating: 2, cacheManager: cacheManager, modelController: modelController)
            }) {
                Label("Recommend occasionally", systemImage: "circle")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Button(action: {
                viewModel.updateRating(for: selectedResult, rating: 3,  cacheManager: cacheManager, modelController: modelController)
            }) {
                Label("Recommend often", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func deleteTasteItem(at idsToDelete: [UUID]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedTasteResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deleteCategoryItem(at idsToDelete: [UUID]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedCategoricalResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Category", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete: [UUID]) {
        for id in idsToDelete {
            Task(priority: .userInitiated) {
                if let parent = modelController.cachedPlaceResult(for: id, cacheManager: cacheManager),
                   let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await viewModel.removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController: modelController)
                    _ = try? await cacheManager.cloudCache.deleteRecommendationData(for: fsqID)
                }
            }
        }
    }
}
