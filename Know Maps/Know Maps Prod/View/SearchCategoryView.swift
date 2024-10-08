//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject public var modelController:DefaultModelController
    @Binding public var selectedCategoryID:CategoryResult.ID?
    var body: some View {
        List(selection:$selectedCategoryID) {
            ForEach(modelController.industryResults, id:\.id){ parent in
                DisclosureGroup(isExpanded: Binding(
                    get: { parent.isExpanded },
                    set: { parent.isExpanded = $0 }
                )){
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
        .listStyle(.sidebar)
        .refreshable {
            Task {
                do{
                    try await cacheManager.refreshCache()
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                }
            }
        }
    }
}
