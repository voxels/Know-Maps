import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
            List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
                HStack {
                    let isSaved = model.cachedTastes(contains: parent.parentCategory)

                    HStack {
                        Text("\(parent.parentCategory)")
                        Spacer()
                        isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                    }                }
                .onAppear {
                    if let last = model.tasteResults.last, parent == last {
                        isLoadingNextPage = true
                        Task {
                            do {
                                try await model.refreshTastes(page: model.lastFetchedTastePage + 1)
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
                    model.lastFetchedTastePage = 0
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
