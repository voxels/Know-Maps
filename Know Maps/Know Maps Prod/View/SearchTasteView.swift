import SwiftUI

struct SearchTasteView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var multiSelection: Set<UUID>
    @Binding public var section: Int
    @State private var isPresented:Bool = true
    @State private var isLoadingNextPage = false
    @State private var tasteSearchText:String = ""
    var body: some View {
        List(modelController.tasteResults, id:\.id, selection: $multiSelection) { parent in
            HStack {
                Text("\(parent.parentCategory)")
                Spacer()
                ratingButton(for: parent)
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
        #if os(macOS)
        .searchable(text:  $tasteSearchText, prompt: "Search for an item")
        #else
        .searchable(text:  $tasteSearchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for an item")

        #endif
        .onSubmit(of: .search, {
            Task(priority:.userInitiated) { @MainActor in
                modelController.tasteResults.removeAll()
                do {
                    try await chatModel.didSearch(caption:tasteSearchText, selectedDestinationChatResultID:modelController.selectedDestinationLocationChatResult, intent:.AutocompleteTastes, filters: [:], cacheManager: cacheManager, modelController: modelController)
                } catch {
                    modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        })
        .listStyle(.sidebar)

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
        switch parent.rating {
        case ..<1:
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Never", systemImage: "circle.slash")
                    .foregroundColor(.red)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        case 1..<3:
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Occasionally", systemImage: "circle")
                    .foregroundColor(.accentColor)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        case 3...:
            Button(action: {
                searchSavedViewModel.editingRecommendationWeightResult = parent
            }) {
                Label("Often", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .frame(width: 44, height:44)
            .buttonStyle(BorderlessButtonStyle())
            .labelStyle(.iconOnly)
        default:
            EmptyView()
        }
    }
}
