//
//  SearchTasteView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    
    var body: some View {
        List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
            HStack {
                Text("\(parent.parentCategory)")
                Spacer()
                if let chatResults = parent.categoricalChatResults, chatResults.count == 1, model.cloudCache.hasPrivateCloudAccess {
                    let isSaved = model.cachedTastes(contains: parent.parentCategory)
                    Label("Save", systemImage:isSaved ? "star.fill" : "star").labelStyle(.iconOnly)
                        .onTapGesture {
                            if isSaved {
                                if let cachedTasteResults = model.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                                    for cachedTasteResult in cachedTasteResults {
                                        Task {
                                            try await model.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                            try await model.refreshTastes(page:model.lastFetchedTastePage)
                                        }
                                    }
                                }
                            } else {
                                Task {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "")
                                    let record = try await model.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                    userRecord.setRecordId(to: record.recordID.recordName)
                                    model.appendCachedTaste(with: userRecord)
                                }
                            }
                        }
                }
            }.onAppear {
                if model.tasteResults.last == parent {
                    Task {
                        do {
                            try await model.refreshTastes(page:model.lastFetchedTastePage + 1)
                        } catch {
                            model.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }
        }
        .task {
            do {
                try await model.refreshTastes(page:0)
            } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return SearchTasteView(model: chatModel)
}
