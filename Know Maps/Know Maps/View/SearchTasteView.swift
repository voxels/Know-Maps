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
                if model.cloudCache.hasPrivateCloudAccess {
                    let isSaved = model.cachedTastes(contains: parent.parentCategory)
                    Label("Save", systemImage:isSaved ? "star.fill" : "star").labelStyle(.iconOnly)
                        .onTapGesture {
                            if isSaved {
                                if let cachedTasteResults = model.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                                    for cachedTasteResult in cachedTasteResults {
                                        Task { @MainActor in
                                            try await model.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                            try await model.refreshCache(cloudCache: model.cloudCache)
                                        }
                                    }
                                }
                            } else {
                                Task {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                                    let record = try await model.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                    userRecord.setRecordId(to: record.recordID.recordName)
                                    model.appendCachedTaste(with: userRecord)
                                    try await model.refreshTastes(page:model.lastFetchedTastePage)
                                    try await model.refreshCache(cloudCache: model.cloudCache)

                                }
                            }
                        }
                }
            }.onAppear {
                if model.tasteResults.last == parent {
                    Task { @MainActor in
                        do {
                            try await model.refreshTastes(page:model.lastFetchedTastePage + 1)
                        } catch {
                            model.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }
        }.refreshable {
            Task { @MainActor in
                do {
                    try await model.refreshTastes(page:model.lastFetchedTastePage)
                } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }.onAppear(perform: {
            Task { @MainActor in
                do {
                    if model.tasteResults.isEmpty {
                        try await model.refreshTastes(page:model.lastFetchedTastePage)
                    }
                } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        })
        .onDisappear(perform: {
            Task { @MainActor in
                do {
                    try await model.refreshTastes(page:model.lastFetchedTastePage)
                } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        })
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return SearchTasteView(model: chatModel)
}
