//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    @ObservedObject public var model:ChatResultViewModel
    
    var body: some View {
        List(model.categoryResults, children:\.children, selection:$model.selectedCategoryResult) { parent in
            HStack {
                Text("\(parent.parentCategory)")
                Spacer()
                if let chatResults = parent.categoricalChatResults, chatResults.count == 1, model.cloudCache.hasPrivateCloudAccess {
                    let isSaved = model.cachedCategories(contains: parent.parentCategory)
                    Label("Save", systemImage:isSaved ? "star.fill" : "star").labelStyle(.iconOnly)
                        .onTapGesture {
                            if isSaved {
                                if let cachedCategoricalResults = model.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) {
                                    for cachedCategoricalResult in cachedCategoricalResults {
                                        Task {
                                            try await model.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                                            try await model.refreshCache(cloudCache: model.cloudCache)
                                        }
                                    }
                                }
                            } else {
                                Task {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Category", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                                    let record = try await model.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                    if let resultName = record.saveResults.keys.first?.recordName {
                                        userRecord.setRecordId(to:resultName)
                                    }
                                    model.appendCachedCategory(with: userRecord)
                                    model.refreshCachedResults()
                                }
                            }
                        }
                }
            }
        }.refreshable {
            model.isRefreshingCache = false
            Task {
                do{
                    try await model.refreshCache(cloudCache: model.cloudCache)
                } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }.task {
            Task {
                do {
                    try await model.refreshCache(cloudCache: model.cloudCache)
                } catch {
                    print(error)
                    model.analytics?.track(name: "error \(error)")
                }
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    return SearchCategoryView(model: chatModel)
}
