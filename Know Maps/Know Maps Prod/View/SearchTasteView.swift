import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject public var modelController:DefaultModelController
    @Binding public var selectedCategoryID:CategoryResult.ID?
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
        List(modelController.tasteResults, id:\.id, selection: $selectedCategoryID) { parent in
            HStack {
                let isSaved = cacheManager.cachedTastes(contains: parent.parentCategory)
                
                HStack {
                    Text("\(parent.parentCategory)")
                    Spacer()
                    isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
                }
            }
            .onAppear {
                if let last = modelController.tasteResults.last, parent == last {
                    isLoadingNextPage = true
                    Task { @MainActor in
                        do {
                            modelController.tasteResults = try await modelController.placeSearchService.refreshTastes(page: modelController.placeSearchService.lastFetchedTastePage + 1, currentTasteResults: modelController.tasteResults, cacheManager: cacheManager)
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: ["page": modelController.placeSearchService.lastFetchedTastePage + 1])
                        }
                        isLoadingNextPage = false
                    }
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                do {
                    modelController.tasteResults = try await modelController.placeSearchService.refreshTastes(page:0, currentTasteResults: [], cacheManager: cacheManager)
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        }
        .refreshable {
            Task { @MainActor in
                do {
                    modelController.tasteResults = try await modelController.placeSearchService.refreshTastes(page:0, currentTasteResults: [], cacheManager: cacheManager)
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        }
        .listStyle(.sidebar)
        .padding(.top, 64)
        .overlay(alignment: .top, content: {
            VStack(alignment: .center) {
                TextField("", text: $tasteSearchText, prompt:Text("Search for a feature"))
                    .onSubmit() {
                        Task { @MainActor in
                            modelController.tasteResults.removeAll()
                            do {
                                try await chatModel.didSearch(caption:tasteSearchText, selectedDestinationChatResultID:modelController.selectedDestinationLocationChatResult, intent:.AutocompleteTastes, cacheManager: cacheManager, modelController: modelController)
                            } catch {
                                modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }
        })
    }
}
