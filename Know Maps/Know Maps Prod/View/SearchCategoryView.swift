//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var multiSelection: Set<UUID>
    @Binding public var addItemSection: Int
    
    @State private var expandedParents: Set<UUID> = []
    @State private var searchText: String = "" // State for search text
    
    var body: some View {
        List(selection: $multiSelection) {
            // Use filtered results here
            ForEach(modelController.industryResults, id: \.id) { parent in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedParents.contains(parent.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedParents.insert(parent.id)
                                } else {
                                    expandedParents.remove(parent.id)
                                }
                            }
                        )
                    ) {
                        ForEach(filteredChildren(for: parent), id: \.id) { child in
                            let isSaved =
                            cacheManager.cachedCategories(contains: child.parentCategory)
                            HStack {
                                Text(child.parentCategory)
                                Spacer()
                                isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                            }
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
        .listStyle(.sidebar)

        #if os(macOS)
        .searchable(text: $searchText, prompt: "Search Categories")
        #else
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Categories") // Add searchable
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
        .onChange(of: searchText) { _ in
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
