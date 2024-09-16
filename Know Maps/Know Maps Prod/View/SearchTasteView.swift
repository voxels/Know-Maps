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
        Section {
            List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
                HStack {
                    if model.cloudCache.hasPrivateCloudAccess {
                        ZStack {
                            Capsule()
#if os(macOS)
                                .foregroundStyle(.background)
                                .frame(width: 44, height:44).padding(8)
#else
                                .foregroundColor(Color(uiColor:.systemFill))
                                .frame(width: 44, height:44).padding(8)
#endif
                            let isSaved = model.cachedTastes(contains: parent.parentCategory)
                            Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                        }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                            .onTapGesture {
                            let isSaved = model.cachedTastes(contains: parent.parentCategory)
                            if isSaved {
                                if let cachedTasteResults = model.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                                    for cachedTasteResult in cachedTasteResults {
                                        Task {
                                            do {
                                            try await model.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                            try await model.refreshCache(cloudCache: model.cloudCache)
                                            } catch {
                                                model.analytics?.track(name: "error \(error)")
                                                print(error)
                                            }

                                        }
                                    }
                                }
                            } else {
                                Task {
                                    do {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                                    let record = try await model.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                    if let resultName = record.saveResults.keys.first?.recordName {
                                        userRecord.setRecordId(to:resultName)
                                    }
                                    model.appendCachedTaste(with: userRecord)
                                        try await model.refreshTastes(page:model.lastFetchedTastePage)
                                    } catch { 
                                        model.analytics?.track(name: "error \(error)")
                                        print(error)
                                    }
                                }
                            }
                        }
                    }
                    if model.cloudCache.hasPrivateCloudAccess {
                        let isSaved = model.cachedTastes(contains: parent.parentCategory)
                        Label("Is Saved", systemImage:isSaved ? "star.fill" : "star").labelStyle(.iconOnly)
                    }
                    Text("\(parent.parentCategory)")
                    Spacer()


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
            .listStyle(.sidebar)
            .onAppear {
                guard model.tasteResults.isEmpty else {
                    return
                }
                
                Task {
                    do {
                        try await model.refreshTastes(page:model.lastFetchedTastePage)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .onDisappear {
                Task {
                    do {
                        try await model.refreshTastes(page:model.lastFetchedTastePage)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .refreshable {
                Task {
                    do {
                        try await model.refreshTastes(page:model.lastFetchedTastePage)
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
        } footer: {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { @MainActor in
                    do {
                        model.tasteResults.removeAll()
                        model.lastFetchedTastePage = 0
                        try await model.refreshTastes(page:model.lastFetchedTastePage)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }.labelStyle(.iconOnly).padding(16)
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    return SearchTasteView(model: chatModel)
}
