import SwiftUI

struct SearchTasteView: View {
    var chatModel:ChatResultViewModel
    var cacheManager:CloudCacheManager
    var modelController:DefaultModelController
    var searchSavedViewModel:SearchSavedViewModel
    @Binding public var multiSelection: Set<String>
    @Binding public var section: Int
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    @State private var autocompleteTask: Task<Void, Never>? = nil
    
    private func loadNextPageIfNeeded(for parent: CategoryResult) async {
        guard !isLoadingNextPage else { return }
        if let last = modelController.tasteResults.last, last.id == parent.id {
            isLoadingNextPage = true
            do {
                modelController.tasteResults = try await modelController.placeSearchService.refreshTastes(
                    page: modelController.placeSearchService.lastFetchedTastePage + 1,
                    currentTasteResults: modelController.tasteResults,
                    cacheManager: cacheManager
                )
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: ["page": modelController.placeSearchService.lastFetchedTastePage + 1])
            }
            isLoadingNextPage = false
        }
    }
    
    private func performTasteAutocomplete(for query: String) async {
        do {
            let caption = query
            let selectedDestination = modelController.selectedDestinationLocationChatResult
            let intentKind = AssistiveChatHostService.Intent.AutocompleteTastes
            let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: caption, filters: [:])
            let newIntent = AssistiveChatHostIntent(
                caption: caption,
                intent: intentKind,
                selectedPlaceSearchResponse: nil,
                selectedPlaceSearchDetails: nil,
                placeSearchResponses: [],
                selectedDestinationLocation: selectedDestination,
                placeDetailsResponses: nil,
                queryParameters: queryParameters
            )
            await modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
            try await modelController.searchIntent(intent: newIntent)
        } catch {
            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    private func ratingFor(parent: CategoryResult) -> Int? {
        if let savedItem = cacheManager.cachedTasteResults.first(where: { $0.parentCategory == parent.parentCategory }) {
            return Int( savedItem.rating)
        }
        return nil
    }
    
    private struct TasteRow: View {
        let parent: CategoryResult
        let rating: Int?
        let onEdit: () -> Void

        var body: some View {
            HStack {
                Text(parent.parentCategory)
                Spacer()
                RatingButton(result: parent, rating: rating) {
                    onEdit()
                }
            }
        }
    }
    
    var body: some View {
        List(selection: $multiSelection) {
            ForEach(modelController.tasteResults, id: \.id) { parent in
                TasteRow(parent: parent,
                         rating: ratingFor(parent: parent),
                         onEdit: { searchSavedViewModel.editingRecommendationWeightResult = parent })
                .task {
                    await loadNextPageIfNeeded(for: parent)
                }
            }
        }
        .onChange(of:tasteSearchText, { oldValue, newValue in
            autocompleteTask?.cancel()
            if !newValue.isEmpty, newValue != oldValue {
                autocompleteTask = Task(priority: .userInitiated) {
                    guard !Task.isCancelled else { return }
                    await performTasteAutocomplete(for: newValue)
                }
            }
        })
        .refreshable {
            Task { @MainActor in
                do {
                    modelController.tasteResults = try await modelController.placeSearchService.refreshTastes(page:0, currentTasteResults: [], cacheManager: cacheManager)
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        }
        #if os(macOS)
        .searchable(text:  $tasteSearchText, prompt: "Search for an item")
        #else
        .searchable(text:  $tasteSearchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for an item")

        #endif
        .onSubmit(of: .search, {
            Task(priority:.userInitiated) {
                await performTasteAutocomplete(for: tasteSearchText)
            }
        })
#if !os(macOS)
        .listStyle(.insetGrouped)
        .listRowBackground(Color(.systemGroupedBackground))
        #endif

//        .overlay(alignment: .top, content: {
//            VStack(alignment: .center) {
//                TextField("", text: $tasteSearchText, prompt:Text("Search for a feature"))
//                    .onSubmit() {
//
//                    }
//                    .textFieldStyle(.roundedBorder)
//                    .padding()
//            }
//        })
}
}
