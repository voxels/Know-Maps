import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    @State private var isPresented:Bool = true
    var body: some View {
#if os(visionOS) || os(iOS)
        VStack {
            TextField("", text: $model.locationSearchText, prompt:Text("Search for a taste"))
                .padding(16)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .onSubmit() {
                    if let selectedDestinationLocationChatResult = model.selectedDestinationLocationChatResult {
                        Task {
                            do {
                                try await model.didSearch(caption:model.locationSearchText, selectedDestinationChatResultID:selectedDestinationLocationChatResult, intent:.AutocompleteTastes)
                            } catch {
                                print(error)
                                model.analytics?.track(name: "error \(error)")
                            }
                        }
                    }
                }
            List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
                HStack {
                    if model.cloudCache.hasPrivateCloudAccess {
                        ZStack {
                            Capsule()
                                .foregroundColor(Color(uiColor:.systemFill))
                                .frame(width: 44, height:44).padding(8)
                            let isSaved = model.cachedTastes(contains: parent.parentCategory)
                            Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                        }
                        .hoverEffect(.lift)
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
            .refreshable {
                Task {
                    do {
                        try await model.refreshTastes(page:model.lastFetchedTastePage)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            
        }.padding()
#else
        List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
            HStack {
                if model.cloudCache.hasPrivateCloudAccess {
                    ZStack {
                        Capsule()
                            .foregroundStyle(.background)
                            .frame(width: 44, height:44).padding(8)
                        let isSaved = model.cachedTastes(contains: parent.parentCategory)
                        Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                    }
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
        .refreshable {
            Task {
                do {
                    try await model.refreshTastes(page:model.lastFetchedTastePage)
                } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }
        .searchable(text: $model.locationSearchText, isPresented: $isPresented, prompt: "Search for a taste")
        .searchPresentationToolbarBehavior(.automatic)
        .onSubmit(of: .search) {
            if let selectedDestinationLocationChatResult = model.selectedDestinationLocationChatResult {
                Task {
                    do {
                        try await model.didSearch(caption:model.locationSearchText, selectedDestinationChatResultID:selectedDestinationLocationChatResult, intent:.AutocompleteTastes)
                    } catch {
                        print(error)
                        model.analytics?.track(name: "error \(error)")
                    }
                }
            }
        }
#endif
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    return SearchTasteView(model: chatModel)
}
