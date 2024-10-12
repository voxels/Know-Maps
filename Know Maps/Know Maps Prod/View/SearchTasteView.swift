import SwiftUI

struct SearchTasteView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<UUID>
    @Binding public var addItemSection: Int
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
        List(modelController.tasteResults, id:\.id, selection: $multiSelection) { parent in
            let isSaved = cacheManager.cachedTastes(contains: parent.parentCategory)
            HStack {
                Text("\(parent.parentCategory)")
                Spacer()
                isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
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
        #if os(iOS) || os(visionOS)
        .toolbar {
            if addItemSection == 1 {
                EditButton()
            }
        }
        #endif
        .task{
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
#if os(iOS) || os(visionOS)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
        
        .padding(.top, 64)
        .overlay(alignment: .top, content: {
            VStack(alignment: .center) {
                TextField("", text: $tasteSearchText, prompt:Text("Search for a feature"))
                    .onSubmit() {
                        Task(priority:.userInitiated) { @MainActor in
                            modelController.tasteResults.removeAll()
                            do {
                                try await chatModel.didSearch(caption:tasteSearchText, selectedDestinationChatResultID:modelController.selectedDestinationLocationChatResult, intent:.AutocompleteTastes, filters: [:], cacheManager: cacheManager, modelController: modelController)
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
