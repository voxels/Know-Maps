import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
            List(chatModel.tasteResults, selection: $chatModel.selectedTasteCategoryResult) { parent in
                HStack {
                    let isSaved = chatModel.cacheManager.cachedTastes(contains: parent.parentCategory)

                    HStack {
                        Text("\(parent.parentCategory)")
                        Spacer()
                        isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                    }                }
                .onAppear {
                    if let last = chatModel.tasteResults.last, parent == last {
                        isLoadingNextPage = true
                        Task {
                            do {
                                try await chatModel.refreshTastes(page: chatModel.lastFetchedTastePage + 1)
                            } catch {
                                chatModel.analyticsManager.trackError(error:error, additionalInfo: ["page": chatModel.lastFetchedTastePage + 1])
                            }
                            isLoadingNextPage = false
                        }
                    }
                }
            }
            .onAppear {
                guard chatModel.tasteResults.isEmpty else {
                    return
                }
                
                Task {
                    chatModel.lastFetchedTastePage = 0
                    do {
                        try await chatModel.refreshTastes(page:chatModel.lastFetchedTastePage)
                    } catch {
                        chatModel.analyticsManager.trackError(error:error, additionalInfo: nil)
                    }
                }
            }
            .refreshable {
                Task {
                    do {
                        chatModel.lastFetchedTastePage = 0
                        try await chatModel.refreshTastes(page:chatModel.lastFetchedTastePage)
                    } catch {
                        chatModel.analyticsManager.trackError(error:error, additionalInfo: nil)
                    }
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 64)
            .overlay(alignment: .top, content: {
                VStack(alignment: .center) {
                    TextField("", text: $tasteSearchText, prompt:Text("Search for a feature"))
                        .onSubmit() {
                            Task {
                                chatModel.tasteResults.removeAll()
                                do {
                                    try await chatModel.didSearch(caption:tasteSearchText, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult, intent:.AutocompleteTastes)
                                } catch {
                                    chatModel.analyticsManager.trackError(error:error, additionalInfo: nil)
                                }
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding()
                }
            })
    }
}
