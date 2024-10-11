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
    @Binding  public var selectedCategoryID:CategoryResult.ID?
    @State private var isExpanded:Bool = false
    var body: some View {
        List(selection:$selectedCategoryID) {
            ForEach(modelController.industryResults, id:\.id){ parent in
                DisclosureGroup(isExpanded: Binding(
                    get: { isExpanded },
                    set: { isExpanded = $0 }
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
