import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
        List(chatModel.modelController.tasteResults, id:\.self, selection: $chatModel.modelController.selectedTasteCategoryResult) { parent in
            HStack {
                let isSaved = chatModel.modelController.cacheManager.cachedTastes(contains: parent.parentCategory)
                
                HStack {
                    Text("\(parent.parentCategory)")
                    Spacer()
                    isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                }
            }
            .onAppear {
                if let last = chatModel.modelController.tasteResults.last, parent == last {
                    isLoadingNextPage = true
                    Task {
                        do {
                            chatModel.modelController.tasteResults = try await chatModel.modelController.placeSearchService.refreshTastes(page: chatModel.modelController.placeSearchService.lastFetchedTastePage + 1, currentTasteResults: chatModel.modelController.tasteResults)
                        } catch {
                            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: ["page": chatModel.modelController.placeSearchService.lastFetchedTastePage + 1])
                        }
                        isLoadingNextPage = false
                    }
                }
            }
        }
        .onAppear {
            guard chatModel.modelController.tasteResults.isEmpty else {
                return
            }
            
            Task {
                do {
                    chatModel.modelController.tasteResults = try await chatModel.modelController.placeSearchService.refreshTastes(page:0, currentTasteResults: [])
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        }
        .refreshable {
            Task {
                do {
                    chatModel.modelController.tasteResults = try await chatModel.modelController.placeSearchService.refreshTastes(page:0, currentTasteResults: [])
                } catch {
                    chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
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
                            chatModel.modelController.tasteResults.removeAll()
                            do {
                                try await chatModel.didSearch(caption:tasteSearchText, selectedDestinationChatResultID:chatModel.modelController.selectedDestinationLocationChatResult, intent:.AutocompleteTastes)
                            } catch {
                                chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }
        })
    }
}
