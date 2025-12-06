//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    var chatModel: ChatResultViewModel
    var cacheManager: CloudCacheManager
    var modelController: DefaultModelController
    var searchSavedViewModel:SearchSavedViewModel
    @Binding public var multiSelection: Set<String>
    @Binding public var section: Int
    
    @State private var expandedParents: Set<String> = []
    @State private var searchText: String = "" // State for search text
    
    private func bindingForParentExpansion(id: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { expandedParents.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedParents.insert(id)
                } else {
                    expandedParents.remove(id)
                }
            }
        )
    }
    
    @ViewBuilder
    private func childRow(for child: CategoryResult) -> some View {
        HStack {
            Text(child.parentCategory)
            Spacer()
            let savedItem = cacheManager.cachedIndustryResults.first(where: { $0.parentCategory == child.parentCategory })
            let savedRatingInt: Int? = savedItem.map { Int($0.rating) }
            RatingButton(result: child, rating: savedRatingInt) {
                searchSavedViewModel.editingRecommendationWeightResult = child
            }
        }
    }
    
    var body: some View {
        List(selection: $multiSelection) {
            let parents = modelController.filteredResults
            ForEach(parents, id: \.id) { parent in
                Section {
                    DisclosureGroup(
                        isExpanded: bindingForParentExpansion(id: parent.id)
                    ) {
                        ForEach(filteredChildren(for: parent), id: \.id) { child in
                            childRow(for: child)
                        }
                    } label: {
                        HStack {
                            Text(parent.parentCategory)
                            Spacer()
                        }
                    }
                }
            }
        }
#if !os(macOS)
        .listStyle(.insetGrouped)
        .listRowBackground(Color(.systemGroupedBackground))
        #endif

        #if os(macOS)
        .searchable(text: $searchText, prompt: "Search Categories")
        #else
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Categories") // Add searchable
        #endif
        .onSubmit(of: .search) {
            expandParentsBasedOnSearch()
        }
        .refreshable {
            Task(priority: .userInitiated) {
                do {
                    try await cacheManager.refreshCache()
                } catch {
                    modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                }
            }
        }
        .onChange(of: searchText) { _, _ in
            expandParentsBasedOnSearch()
        }
    }
    
    // Helper function to filter children if needed
    private func filteredChildren(for parent: CategoryResult) -> [CategoryResult] {
        if searchText.isEmpty {
            return parent.children
        } else {
            return parent.children.filter { child in
                child.parentCategory.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Function to expand parents based on search results
    private func expandParentsBasedOnSearch() {
        for parent in modelController.industryResults {
            if !filteredChildren(for: parent).isEmpty {
                expandedParents.insert(parent.id) // Expand parent if it has matching children
            } else {
                expandedParents.remove(parent.id) // Collapse parent if no children match
            }
        }
    }
}

