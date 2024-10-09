import SwiftUI

struct SearchSavedView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager: CloudCacheManager
    @ObservedObject public var modelController: DefaultModelController
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var contentViewDetail: ContentDetailView
    @Binding public var addItemSection: Int
    @Binding public var settingsPresented: Bool
    @State private var showNavigationLocationSheet: Bool = false
    @State private var searchText: String = ""
    @State private var parentLocationResult: LocationResult?

    var body: some View {
        GeometryReader { geometry in
            SavedListView(
                viewModel: viewModel,
                cacheManager: cacheManager,
                modelController: modelController,
                contentViewDetail: $contentViewDetail,
                addItemSection: $addItemSection,
                preferredColumn: $preferredColumn
            )
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    SavedListToolbarView(
                        viewModel: viewModel,
                        cacheManager: cacheManager,
                        modelController: modelController,
                        settingsPresented: $settingsPresented,
                        contentViewDetail: $contentViewDetail,
                        preferredColumn: $preferredColumn,
                        showNavigationLocationSheet: $showNavigationLocationSheet
                    )
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

                    NavigationLocationView(
                        chatModel: chatModel,
                        cacheManager: cacheManager,
                        modelController: modelController
                    )

                    HStack {
                        if let parent = parentLocationResult {
                            let isSaved = cacheManager.cachedLocation(contains: parent.locationName)
                            if isSaved {
                                Button(action: {
                                    if let location = parent.location {
                                        Task {
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
                                        Task {
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
            Task {
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
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject public var modelController:DefaultModelController
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var selectedCategoryID:CategoryResult.ID?
    
    var body: some View {
        TabView(selection: $addItemSection) {
            SearchCategoryView(chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, selectedCategoryID: $selectedCategoryID)
                .tag(0)
                .tabItem {
                    Label("Type", systemImage: "building")
                }
            
            SearchTasteView(chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, selectedCategoryID: $selectedCategoryID)
                .tag(1)
                .tabItem {
                    Label("Item", systemImage: "heart")
                }
            
            SearchPlacesView(chatModel: chatModel, cacheManager: cacheManager, modelController:modelController)
                .tag(2)
                .tabItem {
                    Label("Place", systemImage: "mappin")
                }
        }
    }
}

struct AddPromptToolbarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager: CloudCacheManager
    @ObservedObject public var modelController: DefaultModelController
    @Binding public var addItemSection: Int
    @Binding public var selectedCategoryID:CategoryResult.ID?
    @Binding public var contentViewDetail: ContentDetailView
    @Binding public var preferredColumn: NavigationSplitViewColumn

    @State private var parent: CategoryResult?
    @State private var isSaved: Bool = false

    var body: some View {
        Group {
            if addItemSection == 0 {
                if let parent = parent {
                    if isSaved {
                        Button(action: {
                            Task {
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
                            Task {
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
                            Task {
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
                            Task {
                                await viewModel.addTaste(
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
            }
        }

        Button(action: {
            preferredColumn = .sidebar
            contentViewDetail = .places
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

struct SavedListView: View {
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject public var modelController:DefaultModelController
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var addItemSection:Int
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @State private var selectedResult:CategoryResult.ID?
    @State private var editingResult:CategoryResult?
    var body: some View {
        List(selection: $selectedResult) {
            Section("Types") {
                if !cacheManager.cachedIndustryResults.isEmpty {
                    ForEach(cacheManager.cachedIndustryResults, id:\.id) { parent in
                        HStack {
                            Text(parent.parentCategory)
                            Spacer()
                            if parent.rating <= 0 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Never", systemImage: "circle.slash")
                                        .foregroundStyle(.red)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating > 0 && parent.rating < 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Occasionally", systemImage: "circle")
                                        .foregroundStyle(.accent)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating >= 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Often", systemImage: "circle.fill")
                                        .foregroundStyle(.green)
                                        .labelStyle(.iconOnly)
                                })
                            }
                        }
                    }.onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            cacheManager.cachedIndustryResults[index].id
                        }
                        deleteCategoryItem(at: idsToDelete)
                    }
                    
                }
                
                Text("Add a type")
                    .onTapGesture {
                        addItemSection = 0
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
                    .foregroundStyle(.accent)
                
            }
            
            Section("Items") {
                if !cacheManager.cachedTasteResults.isEmpty {
                    ForEach(cacheManager.cachedTasteResults, id:\.id) { parent in
                        HStack {
                            Text(parent.parentCategory)
                            Spacer()
                            if parent.rating <= 0 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Never", systemImage: "circle.slash")
                                        .foregroundStyle(.red)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating > 0 && parent.rating < 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Occasionally", systemImage: "circle")
                                        .foregroundStyle(.accent)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating >= 3 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Often", systemImage: "circle.fill")
                                        .foregroundStyle(.green)
                                        .labelStyle(.iconOnly)
                                })
                            }
                        }
                    }
                    .onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            cacheManager.cachedTasteResults[index].id
                        }
                        deleteTasteItem(at: idsToDelete)
                    }
                }
                Text("Add an item")
                    .onTapGesture {
                        addItemSection = 1
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
                    .foregroundStyle(.accent)
            }
            
            Section("Places") {
                if !cacheManager.cachedPlaceResults.isEmpty {
                    ForEach(cacheManager.cachedPlaceResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            cacheManager.cachedPlaceResults[index].id
                        }
                        deletePlaceItem(at: idsToDelete)
                    }
                }
                Text("Add a place")
                    .onTapGesture {
                        addItemSection = 2
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
                    .foregroundStyle(.accent)
                
            }
            
            Section("Moods") {
                ForEach(cacheManager.cachedDefaultResults, id:\.id) {
                    parent in
                    Text(parent.parentCategory)
                }
            }
        }
        .onChange(of:selectedResult) { oldValue, newValue in
            guard let newValue = newValue else {
                preferredColumn = .sidebar
                return
            }
            
            preferredColumn = .detail
            DispatchQueue.main.async {
                modelController.selectedSavedResult = newValue
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            Task {
                await viewModel.refreshCache(cacheManager: cacheManager, modelController: modelController)
            }
        }
        .sheet(item: $editingResult, content: { selectedResult in
            VStack {
                Text("\(selectedResult.parentCategory)")
                    .font(.headline)
                Button(action: {
                    Task {
                        do {
                            try await viewModel.changeRating(rating: 0, for: selectedResult.recordId, cacheManager: cacheManager, modelController: modelController)
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Recommend rarely", systemImage: "circle.slash")
                        .foregroundStyle(.red)
                }).padding()
                Button(action: {
                    Task {
                        do {
                            try await viewModel.changeRating(rating: 2, for: selectedResult.recordId, cacheManager: cacheManager, modelController: modelController)
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Recommend occasionally", systemImage: "circle")
                        .foregroundStyle(.accent)
                }).padding()
                Button(action: {
                    Task {
                        do {
                            try await viewModel.changeRating(rating: 3, for: selectedResult.recordId, cacheManager: cacheManager, modelController: modelController)
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Recommend often", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                }).padding()
            }.padding()
        })
        .presentationCompactAdaptation(.sheet)
    }
    
    func removeSelectedItem() async throws {
        if let selectedSavedResult = modelController.selectedSavedResult, let selectedTasteItem = modelController.cachedTasteResult(for: selectedSavedResult, cacheManager: cacheManager) {
            let idsToDelete: [UUID] = [selectedTasteItem.id]
            deleteTasteItem(at: idsToDelete)
        } else if let selectedSavedResult = modelController.selectedSavedResult, let selectedCategoryItem = modelController.cachedCategoricalResult(for: selectedSavedResult, cacheManager: cacheManager){
            let idsToDelete: [UUID] = [selectedCategoryItem.id]
            deleteCategoryItem(at: idsToDelete)
        } else if let selectedSavedResult = modelController.selectedSavedResult, let selectedPlaceItem = modelController.cachedPlaceResult(for: selectedSavedResult, cacheManager: cacheManager) {
            let idsToDelete: [UUID] = [selectedPlaceItem.id]
            deletePlaceItem(at: idsToDelete)
        }
    }
    
    func deleteTasteItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = modelController.cachedTasteResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    
    func deleteCategoryItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = modelController.cachedCategoricalResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Category", identity: parent.parentCategory, cacheManager: cacheManager, modelController: modelController)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete:[UUID]) {
        for id in idsToDelete {
            Task {
                if let parent = modelController.cachedPlaceResult(for: id, cacheManager: cacheManager), let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await viewModel.removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager, modelController:modelController)
                }
            }
        }
    }
}

struct SavedListToolbarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject public var modelController:DefaultModelController
    @Binding public var settingsPresented: Bool
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var showNavigationLocationSheet:Bool
    
    var body: some View {
        if contentViewDetail == .places {
            Button(action: {
                preferredColumn = .detail
                contentViewDetail = .add
            }) {
                Label("Add Prompt", systemImage: "plus.circle")
            }
        }
        
        if let savedResult = modelController.selectedSavedResult  {
            Button(action: {
                Task {
                    do {
                        try await viewModel.removeSelectedItem(selectedSavedResult: savedResult, cacheManager: cacheManager, modelController: modelController)
                    } catch {
                        modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                    }
                }
            }, label: {
                Label("Delete", systemImage: "minus.circle")
            })
        }
        
        Button("Search Location", systemImage:"location.magnifyingglass") {
            showNavigationLocationSheet.toggle()
        }
        Button {
#if os(iOS) || os(visionOS)
            settingsPresented.toggle()
#else
            openWindow(id: "SettingsView")
#endif
        } label: {
            Label("Account Settings", systemImage: "gear")
        }
    }
}
