import SwiftUI

struct SearchSavedView: View {
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding  public var preferredColumn: NavigationSplitViewColumn
    @Binding  public var contentViewDetail: ContentDetailView
    @Binding  public var addItemSection: Int
    @Binding  public var settingsPresented: Bool
    @State private var showNavigationLocationSheet: Bool = false
    @State private var searchText: String = ""
    @State private var parentLocationResult: LocationResult?

    var body: some View {
        GeometryReader { geometry in
            SavedListView(viewModel: $viewModel, cacheManager: $cacheManager, modelController: $modelController, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, preferredColumn: $preferredColumn, selectedResult: $modelController.selectedSavedResult)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    SavedListToolbarView(viewModel: $viewModel, cacheManager: $cacheManager, modelController: $modelController, settingsPresented: $settingsPresented, contentViewDetail: $contentViewDetail, preferredColumn: $preferredColumn, showNavigationLocationSheet: $showNavigationLocationSheet)
                }
            }
            .sheet(isPresented: $showNavigationLocationSheet) {
                VStack {
#if os(macOS)
                    HStack {
                        Spacer()
                        Button(action: {
                            showNavigationLocationSheet = false
                        }, label: {
                            Label("Done", systemImage: "plus.circle")
                                .labelStyle(.titleAndIcon)
                        })
                        .padding()
                    }
#endif
                    HStack {
                        TextField("City, State", text: $searchText)
                            .onSubmit {
                                search()
                            }
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            search()
                        }, label: {
                            Label("Search", systemImage: "magnifyingglass")
                        })
                    }
                    .padding()

                    NavigationLocationView(chatModel: $chatModel, cacheManager: $cacheManager, modelController:$modelController)
                        .task {
                            modelController.selectedSavedResult = nil
                        await modelController.resetPlaceModel()
                    }

                    HStack {
                        if let parent = parentLocationResult {
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
                                            } catch {
                                                modelController.analyticsManager.trackError(
                                                    error: error,
                                                    additionalInfo: nil
                                                )
                                            }
                                        }
                                    }
                                }, label: {
                                    Label("Save", systemImage: "square.and.arrow.down")
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
                .onAppear {
                    updateParentLocationResult()
                }
                .onChange(of: searchText) { _,_ in
                    updateParentLocationResult()
                }
                .onChange(of: modelController.selectedDestinationLocationChatResult) { _,_ in
                    updateParentLocationResult()
                }
            }
        }
    }

    func updateParentLocationResult() {
        if let selectedResult = modelController.selectedDestinationLocationChatResult {
            parentLocationResult = modelController.locationChatResult(
                for: selectedResult,
                in: modelController.filteredLocationResults(cacheManager: cacheManager)
            )
        } else {
            parentLocationResult = modelController.locationResults.first { $0.locationName == searchText }
        }
    }

    func search() {
        if !searchText.isEmpty {
            Task(priority:.userInitiated) {
                await viewModel.search(
                    caption: searchText,
                    selectedDestinationChatResultID: nil,
                    chatModel: chatModel,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
            }
        }
    }
}

struct AddPromptView: View {
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding  public var addItemSection: Int
    @Binding  public var contentViewDetail:ContentDetailView
    @Binding  public var selectedCategoryID:CategoryResult.ID?
    
    var body: some View {
        TabView(selection: $addItemSection) {
            SearchCategoryView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, selectedCategoryID: $selectedCategoryID)
                .tag(0)
                .tabItem {
                    Label("Type", systemImage: "building")
                }
            
            SearchTasteView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, selectedCategoryID: $selectedCategoryID)
                .tag(1)
                .tabItem {
                    Label("Item", systemImage: "heart")
                }
            
            SearchPlacesView(chatModel: $chatModel, cacheManager: $cacheManager, modelController:   $modelController)
                .tag(2)
                .tabItem {
                    Label("Place", systemImage: "mappin")
                }
        }
    }
}

struct AddPromptToolbarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding  public var addItemSection: Int
    @Binding  public var selectedCategoryID:CategoryResult.ID?
    @Binding  public var contentViewDetail: ContentDetailView
    @Binding  public var preferredColumn: NavigationSplitViewColumn

    @State private var parent: CategoryResult?
    @State private var isSaved: Bool = false

    var body: some View {
        Group {
            if addItemSection == 0 {
                if let parent = parent {
                    if isSaved {
                        Button(action: {
                            Task(priority:.userInitiated) {
                                await viewModel.removeCategory(
                                    parent: parent,
                                    cacheManager: cacheManager,
                                    modelController: modelController
                                )
                            }
                        }) {
                            Label("Delete", systemImage: "minus.circle")
                        }
                        .labelStyle(.titleAndIcon)
                    } else {
                        Button(action: {
                            Task(priority:.userInitiated) {
                                await viewModel.addCategory(
                                    parent: parent,
                                    cacheManager: cacheManager,
                                    modelController: modelController
                                )
                            }
                        }) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            } else if addItemSection == 1 {
                if let parent = parent {
                    if isSaved {
                        Button(action: {
                            Task(priority:.userInitiated) {
                                await viewModel.removeTaste(
                                    parent: parent,
                                    cacheManager: cacheManager,
                                    modelController: modelController
                                )
                            }
                        }) {
                            Label("Delete", systemImage: "minus.circle")
                        }
                        .labelStyle(.titleAndIcon)
                    } else {
                        Button(action: {
                            Task(priority:.userInitiated) {
                                await viewModel.addTaste(
                                    title: parent.parentCategory,
                                    cacheManager: cacheManager,
                                    modelController: modelController
                                )
                            }
                        }) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
        }

        Button(action: {
            preferredColumn = .sidebar
        }) {
            Label("Done", systemImage: "checkmark.circle")
        }
        .onAppear {
            updateParent()
        }
        .onChange(of: selectedCategoryID) { _,_ in
            updateParent()
        }
        .onChange(of: addItemSection) { _,_ in
            updateParent()
        }
    }

    func updateParent() {
        if addItemSection == 0,
           let parentID = selectedCategoryID,
           let parentResult = modelController.industryCategoryResult(for: parentID) {
            parent = parentResult
            isSaved = cacheManager.cachedCategories(contains: parentResult.parentCategory)
        } else if addItemSection == 1,
                  let parentID = selectedCategoryID,
                  let parentResult = modelController.tasteCategoryResult(for: parentID) {
            parent = parentResult
            isSaved = cacheManager.cachedTastes(contains: parentResult.parentCategory)
        } else {
            parent = nil
            isSaved = false
        }
    }
}
