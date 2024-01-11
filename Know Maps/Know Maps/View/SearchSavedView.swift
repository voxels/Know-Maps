//
//  SearchSavedView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchSavedView: View {
    @ObservedObject public var model:ChatResultViewModel
    
    var body: some View {
        List(model.cachedCategoryResults, children:\.children, selection: $model.selectedSavedCategoryResult) { parent in
            HStack {
                Text("\(parent.parentCategory)")
                Spacer()
                if let chatResults = parent.categoricalChatResults, chatResults.count == 1, model.cloudCache.hasPrivateCloudAccess {
                    Label("Save", systemImage:"star.fill")
                        .labelStyle(.iconOnly)
                        .onTapGesture {
                            if let cachedCategoricalResults = model.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) {
                                for cachedCategoricalResult in cachedCategoricalResults {
                                    Task { @MainActor in
                                        try await model.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                                        try await model.refreshCachedCategories(cloudCache: model.cloudCache)
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    return SearchSavedView(model: chatModel)
}
