import SwiftUI

struct SearchSavedView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var addItemSection: Int
    @Binding public var settingsPresented: Bool
    @Binding public var showNavigationLocationSheet: Bool
    @State private var searchText: String = ""

    var body: some View {
        GeometryReader { geometry in
            SavedListView(viewModel: $viewModel, cacheManager: $cacheManager, modelController: $modelController, addItemSection: $addItemSection, preferredColumn: $preferredColumn, selectedResult: $modelController.selectedSavedResult)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        showNavigationLocationSheet.toggle()
                    }) {
                        Label("Search Location", systemImage: "location.magnifyingglass")
                    }
                    Button(action: {
            #if os(iOS) || os(visionOS)
                        settingsPresented.toggle()
            #else
                        openWindow(id: "SettingsView")
            #endif
                    }) {
                        Label("Account Settings", systemImage: "gear")
                    }

                }
            }
            .sheet(isPresented: $showNavigationLocationSheet) {
                VStack {
                    HStack {
                        TextField("City, State", text: $searchText)
                            .onSubmit {
                                search(intent:.Location)
                            }
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            search(intent:.Location)
                        }, label: {
                            Label("Search", systemImage: "magnifyingglass")
                        })
                    }
                    .padding()

                    NavigationLocationView(chatModel: $chatModel, cacheManager: $cacheManager, modelController:$modelController)

                    HStack {
                        Button(action:{
                            showNavigationLocationSheet.toggle()
                        }, label:{
                            Label("List", systemImage: "list.bullet")
                        }).padding()
                        Spacer()
                        if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let parent =  modelController.locationChatResult(
                            for: selectedDestinationLocationChatResult,in: modelController.filteredLocationResults(cacheManager: cacheManager)) {
                            let isSaved = cacheManager.cachedLocation(contains: parent.locationName)
                            if isSaved {
                                Button(action: {
                                    if let location = parent.location {
                                        Task(priority:.userInitiated) {
                                            await viewModel.removeCachedResults(
                                                group: "Location",
                                                identity: cacheManager.cachedLocationIdentity(for: location),
                                                cacheManager: cacheManager,
                                                modelController: modelController
                                            )
                                        }
                                    }
                                }, label: {
                                    Label("Delete", systemImage: "minus.circle")
                                })
                                .labelStyle(.titleAndIcon)
                                .padding()
                            } else {
                                Button(action: {
                                    if let location = parent.location {
                                        Task(priority:.userInitiated) {
                                            do {
                                                try await viewModel.addLocation(
                                                    parent: parent,
                                                    location: location,
                                                    cacheManager: cacheManager,
                                                    modelController: modelController
                                                )
                                                modelController.selectedDestinationLocationChatResult = modelController.filteredLocationResults(cacheManager:cacheManager).first(where: {$0.locationName == parent.locationName})?.id
                                            } catch {
                                                modelController.analyticsManager.trackError(
                                                    error: error,
                                                    additionalInfo: nil
                                                )
                                            }
                                        }
                                    }
                                }, label: {
                                    Label("Save", systemImage: "plus.circle")
                                })
                                .labelStyle(.titleAndIcon)
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
                .padding()
                .frame(minHeight: geometry.size.height, maxHeight: .infinity)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCompactAdaptation(.sheet)
            }
        }
    }
    
    func search(intent:AssistiveChatHostService.Intent) {
        if !searchText.isEmpty {
            Task(priority:.userInitiated) {
                await viewModel.search(
                    caption: searchText,
                    selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult, intent: intent, filters: viewModel.filters,
                    chatModel: chatModel,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
            }
        }
    }
}

