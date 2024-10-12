//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<UUID>
    @Binding public var addItemSection: Int
    @State private var expandedParents: Set<UUID> = []
    var body: some View {
        List(selection:$multiSelection) {
            ForEach(modelController.industryResults, id:\.id){ parent in
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
                    ForEach(parent.children, id:\.id) { child in
                        let isSaved = cacheManager.cachedCategories(contains: child.parentCategory)
                        HStack {
                            Text("\(child.parentCategory)")
                            Spacer()
                            isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                        }
                    }
                } label: {
                    HStack {
                        Text("\(parent.parentCategory)")
                        Spacer()
                    }
                }
            }
        }
        .toolbar {
            if addItemSection == 0 {
                EditButton()
            }
        }
        .listStyle(.sidebar)
#if os(iOS) || os(visionOS)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
        
        .refreshable {
            Task(priority:.userInitiated) {
                do{
                    try await cacheManager.refreshCache()
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                }
            }
        }
    }
}
