import SwiftUI

struct SearchTasteView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var multiSelection: Set<String>
    @Binding public var section: Int
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    @State private var autocompleteTask: Task<Void, Never>? = nil
    var body: some View {
        List(selection: $multiSelection) {
            // Default paged tastes list
            ForEach(modelController.tasteResults, id: \.id) { parent in
                HStack {
                    Text("\(parent.parentCategory)")
                    Spacer()
                    ratingButton(for: parent)
                }
                .task {
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
        }
        .onChange(of:tasteSearchText, { oldValue, newValue in
            autocompleteTask?.cancel()
            if !newValue.isEmpty, newValue != oldValue {
                autocompleteTask = Task(priority:.userInitiated) { @MainActor in
                    do {
                        let caption = tasteSearchText
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
                        if let autocompleteTask, autocompleteTask.isCancelled {
                            return
                        }
                        await modelController.assistiveHostDelegate.appendIntentParameters(intent: newIntent, modelController: modelController)
                        try await modelController.searchIntent(intent: newIntent)
                    } catch {
                         modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                    }
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
            Task(priority:.userInitiated) { @MainActor in
                do {
                    let caption = tasteSearchText
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
                     modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
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
    
    
    @ViewBuilder
    func ratingButton(for parent: CategoryResult) -> some View {
        
        let isSaved = cacheManager.cachedPlaceResults.contains(where: { $0.parentCategory == parent.parentCategory })
        
        if isSaved, let rating = cacheManager.cachedPlaceResults.first(where: { $0.parentCategory == parent.parentCategory })?.rating {
            switch rating {
            case ..<1:
                Button(action: {
                    searchSavedViewModel.editingRecommendationWeightResult = parent
                }) {
                    Label("Never", systemImage: "star.slash")
                        .foregroundColor(.red)
                }
                .frame(width: 44, height:44)
                .buttonStyle(BorderlessButtonStyle())
                .labelStyle(.iconOnly)
            case 1..<3:
                Button(action: {
                    searchSavedViewModel.editingRecommendationWeightResult = parent
                }) {
                    Label("Occasionally", systemImage: "star.leadinghalf.filled")
                        .foregroundColor(.accentColor)
                }
                .frame(width: 44, height:44)
                .buttonStyle(BorderlessButtonStyle())
                .labelStyle(.iconOnly)
            case 3...:
                Button(action: {
                    searchSavedViewModel.editingRecommendationWeightResult = parent
                }) {
                    Label("Often", systemImage: "star.fill")
                        .foregroundColor(.green)
                }
                .frame(width: 44, height:44)
                .buttonStyle(BorderlessButtonStyle())
                .labelStyle(.iconOnly)
            default:
                EmptyView()
            }
        } else {
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Occasionally", systemImage: "star.leadinghalf.filled")
                    .foregroundColor(.accentColor)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        }
    }
    
}

