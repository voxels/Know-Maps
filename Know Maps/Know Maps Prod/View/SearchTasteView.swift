import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    @State private var searchText:String = ""
    @State private var isPresented:Bool = false
    var body: some View {
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
            .searchable(text: $searchText, isPresented: $isPresented, prompt: "Search for a taste")
            .onSubmit(of: .search) {
                
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
