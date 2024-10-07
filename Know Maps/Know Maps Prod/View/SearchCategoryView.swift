//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    
    var body: some View {
        List(selection:$chatModel.selectedCategoryResult) {
            ForEach(chatModel.industryResults, id:\.id){ parent in
                DisclosureGroup(isExpanded: Binding(
                    get: { parent.isExpanded },
                    set: { parent.isExpanded = $0 }
                )){
                    ForEach(parent.children, id:\.id) { child in
                        let isSaved = chatModel.cacheManager.cachedCategories(contains: child.parentCategory)
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
                    try await chatModel.cacheManager.refreshCache()
                } catch {
                    chatModel.analyticsManager.trackError(error:error, additionalInfo:nil)
                }
            }
        }
    }
}
