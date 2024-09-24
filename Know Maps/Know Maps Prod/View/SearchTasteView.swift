import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
            List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
                HStack {
                    if model.cloudCache.hasPrivateCloudAccess {
                        ZStack {
                            Capsule()
    #if os(macOS)
                                .foregroundStyle(.background)
                                .frame(width: 44, height:44)
                                .padding(8)
    #else
                                .foregroundColor(Color(uiColor:.systemFill))
                                .frame(width: 44, height: 44, alignment: .center)
                                .padding(8)
    #endif
                            let isSaved = model.cachedTastes(contains: parent.parentCategory)
                            Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                        }
                        .foregroundStyle(.accent)
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
                                        userRecord.setRecordId(to:record)
                                        model.appendCachedTaste(with: userRecord)
                                        model.refreshCachedResults()
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
                .onAppear {
                    if let last = model.tasteResults.last, parent == last {
                        isLoadingNextPage = true
                        Task {
                            do {
                                try await model.refreshTastes(page: model.lastFetchedTastePage)
                            } catch {
                                model.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                            isLoadingNextPage = false
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
            .listStyle(.sidebar)
            .padding(.top, 64)
            .overlay(alignment: .top, content: {
                VStack(alignment: .center) {
                    TextField("", text: $tasteSearchText, prompt:Text("Search for a taste"))
                        .onSubmit() {
                            Task {
                                model.tasteResults.removeAll()
                                do {
                                    try await model.didSearch(caption:tasteSearchText, selectedDestinationChatResultID:model.selectedDestinationLocationChatResult, intent:.AutocompleteTastes)
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
