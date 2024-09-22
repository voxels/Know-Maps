import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    @State private var isPresented:Bool = true
    var body: some View {
            List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
                HStack {
                    if model.cloudCache.hasPrivateCloudAccess {
                        ZStack {
                            Capsule()
                            #if os(visionOS) || os(iOS)
                                .foregroundColor(Color(uiColor:.systemFill))
#endif
                                .frame(width: 44, height:44).padding(8)
                            let isSaved = model.cachedTastes(contains: parent.parentCategory)
                            Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                        }
#if os(visionOS) || os(iOS)
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
            .padding(.top, 36)
            .overlay(alignment: .top, content: {
                VStack(alignment: .center) {
                    TextField("", text: $model.locationSearchText, prompt:Text("Search for a taste"))
                        .onSubmit() {
                            Task {
                                do {
                                    try await model.didSearch(caption:model.locationSearchText, selectedDestinationChatResultID:model.selectedDestinationLocationChatResult, intent:.AutocompleteTastes)
                                } catch {
                                    print(error)
                                    model.analytics?.track(name: "error \(error)")
                                }
                            }
                        }.padding()
                }
            })
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    return SearchTasteView(model: chatModel)
}
