import SwiftUI

struct SearchSavedView: View {
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var contentViewDetail: ContentDetailView
    @Binding public var addItemSection: Int
    @Binding public var settingsPresented: Bool
    @State private var showNavigationLocationSheet: Bool = false
    @State private var searchText: String = ""
    
    
    var body: some View {
        GeometryReader { geometry in
            SavedListView(viewModel:viewModel, cacheManager: cacheManager, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, preferredColumn: $preferredColumn)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        SavedListToolbarView(
                            viewModel: viewModel, cacheManager: cacheManager,
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
                                Label("Done", systemImage: "plus.circle").labelStyle(.titleAndIcon)
                            }).padding()
                        }
#endif
                        HStack {
                            TextField("City, State", text: $searchText)
                                .onSubmit {
                                    search()
                                }
                                .textFieldStyle(.roundedBorder)
                            Button("Search", systemImage: "magnifyingglass") {
                                search()
                            }
                        }.padding()
                        NavigationLocationView(chatModel: viewModel.chatModel, cacheManager: cacheManager)
                        HStack {
                            if let selectedDestinationLocationChatResult = viewModel.chatModel.modelController.selectedDestinationLocationChatResult,
                               let parent = viewModel.chatModel.modelController.locationChatResult(for: selectedDestinationLocationChatResult, in:viewModel.chatModel.modelController.filteredLocationResults(cacheManager: cacheManager))
                            {
                                let isSaved = cacheManager.cachedLocation(contains:parent.locationName)
                                if isSaved {
                                    Button("Delete", systemImage:"minus.circle") {
                                        if let location = parent.location {
                                            Task {
                                                await viewModel.removeCachedResults(group: "Location", identity:cacheManager.cachedLocationIdentity(for: location), cacheManager: cacheManager)
                                            }
                                        }
                                    }.labelStyle(.titleAndIcon)
                                        .padding()
                                } else {
                                    Button("Save", systemImage:"square.and.arrow.down") {
                                        if let location = parent.location {
                                            Task {
                                                do {
                                                    try await viewModel.addLocation(parent: parent, location: location, cacheManager: cacheManager)
                                                } catch {
                                                    viewModel.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                                                }
                                            }
                                        }
                                    }.labelStyle(.titleAndIcon)
                                        .padding()
                                }
                            } else if let parent = viewModel.chatModel.modelController.locationResults.first(where: {$0.locationName == searchText}) {
                                Button("Save", systemImage:"square.and.arrow.down") {
                                    Task{
                                        if let location = parent.location {
                                            do {
                                                try await viewModel.addLocation(parent: parent, location: location, cacheManager: cacheManager)
                                            } catch {
                                                viewModel.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                                            }
                                        }
                                    }
                                }.labelStyle(.titleAndIcon)
                                    .padding()
                            }
                        }.padding()
                        // Sheet content
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height, maxHeight: .infinity)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCompactAdaptation(.sheet)
                }
        }
    }
    
    func search() {
        if !searchText.isEmpty {
            Task {
                await viewModel.search(caption: searchText, selectedDestinationChatResultID: nil, cacheManager: cacheManager)
            }
        }
    }
}

struct AddPromptView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        TabView(selection: $addItemSection) {
            SearchCategoryView(chatModel: chatModel, cacheManager: cacheManager)
                .tag(0)
                .tabItem {
                    Label("Type", systemImage: "building")
                }
            
            SearchTasteView(chatModel: chatModel, cacheManager: cacheManager)
                .tag(1)
                .tabItem {
                    Label("Item", systemImage: "heart")
                }
            
            SearchPlacesView(chatModel: chatModel, cacheManager: cacheManager)
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
    @ObservedObject public var cacheManager:CloudCacheManager
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var preferredColumn:NavigationSplitViewColumn
    
    var body: some View {
        if addItemSection == 0,
           let parentID = viewModel.chatModel.modelController.selectedCategoryResult,
           let parent = viewModel.chatModel.modelController.industryCategoryResult(for: parentID) {
            let isSaved = cacheManager.cachedCategories(contains: parent.parentCategory)
            if isSaved {
                Button(action:{
                    Task {
                        await viewModel.removeCategory(parent: parent, cacheManager: cacheManager)
                    }
                }) {
                    Label("Delete", systemImage: "minus.cicle")
                }
                .labelStyle(.titleAndIcon)
            } else {
                Button(action: {
                    Task {
                        await viewModel.addCategory(parent: parent, cacheManager: cacheManager)
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                
            }
        } else if addItemSection == 1,
                  let parentID = viewModel.chatModel.modelController.selectedTasteCategoryResult,
                  let parent = viewModel.chatModel.modelController.tasteCategoryResult(for: parentID) {
            let isSaved = cacheManager.cachedTastes(contains: parent.parentCategory)
            if isSaved {
                Button(action: {
                    Task {
                        await viewModel.removeTaste(parent: parent, cacheManager: cacheManager)
                    }
                }) {
                    Label("Delete", systemImage: "minus.circle")
                }.labelStyle(.titleAndIcon)
            } else {
                Button(action: {
                    Task {
                        await viewModel.addTaste(parent: parent, cacheManager: cacheManager)
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }.labelStyle(.titleAndIcon)
            }
        } else {
            
        }
        
        Button(action: {
            preferredColumn = .sidebar
            contentViewDetail = .places
        }) {
            Label("Done", systemImage: "checkmark.circle")
        }
    }
}

struct SavedListView: View {
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
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
                            if parent.rating == 0 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Never", systemImage: "circle.slash")
                                        .foregroundStyle(.red)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating == 1 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Occasionally", systemImage: "circle")
                                        .foregroundStyle(.accent)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating == 2 {
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
                            if parent.rating == 0 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Never", systemImage: "circle.slash")
                                        .foregroundStyle(.red)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating == 1 {
                                Button(action: {
                                    editingResult = parent
                                }, label: {
                                    Label("Occasionally", systemImage: "circle")
                                        .foregroundStyle(.accent)
                                        .labelStyle(.iconOnly)
                                })
                            } else if parent.rating == 2 {
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
            viewModel.chatModel.modelController.selectedSavedResult = newValue
        }
        .listStyle(.sidebar)
        .refreshable {
            Task {
                await viewModel.refreshCache(cacheManager: cacheManager)
            }
        }
        .sheet(item: $editingResult, content: { selectedResult in
            VStack {
                Button(action: {
                    Task {
                        do {
                            try await viewModel.changeRating(rating: 0, for: selectedResult.recordId, cacheManager: cacheManager)
                        } catch {
                            viewModel.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Never", systemImage: "circle.slash")
                        .foregroundStyle(.red)
                }).padding()
                Button(action: {
                    Task {
                        do {
                            try await viewModel.changeRating(rating: 1, for: selectedResult.recordId, cacheManager: cacheManager)
                        } catch {
                            viewModel.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Occasionally", systemImage: "circle")
                        .foregroundStyle(.accent)
                }).padding()
                Button(action: {
                    Task {
                        do {
                            try await viewModel.changeRating(rating: 2, for: selectedResult.recordId, cacheManager: cacheManager)
                        } catch {
                            viewModel.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                        }
                    }
                    editingResult = nil
                }, label: {
                    Label("Often", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                }).padding()
            }.padding()
        })
        .presentationCompactAdaptation(.sheet)
    }
    
    func removeSelectedItem() async throws {
        if let selectedSavedResult = viewModel.chatModel.modelController.selectedSavedResult, let selectedTasteItem = viewModel.chatModel.modelController.cachedTasteResult(for: selectedSavedResult, cacheManager: cacheManager) {
            let idsToDelete: [UUID] = [selectedTasteItem.id]
            deleteTasteItem(at: idsToDelete)
        } else if let selectedSavedResult = viewModel.chatModel.modelController.selectedSavedResult, let selectedCategoryItem = viewModel.chatModel.modelController.cachedCategoricalResult(for: selectedSavedResult, cacheManager: cacheManager){
            let idsToDelete: [UUID] = [selectedCategoryItem.id]
            deleteCategoryItem(at: idsToDelete)
        } else if let selectedSavedResult = viewModel.chatModel.modelController.selectedSavedResult, let selectedPlaceItem = viewModel.chatModel.modelController.cachedPlaceResult(for: selectedSavedResult, cacheManager: cacheManager) {
            let idsToDelete: [UUID] = [selectedPlaceItem.id]
            deletePlaceItem(at: idsToDelete)
        }
    }
    
    func deleteTasteItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = viewModel.chatModel.modelController.cachedTasteResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory, cacheManager: cacheManager)
                }
            }
        }
    }
    
    
    func deleteCategoryItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = viewModel.chatModel.modelController.cachedCategoricalResult(for: id, cacheManager: cacheManager) {
                    await viewModel.removeCachedResults(group: "Category", identity: parent.parentCategory, cacheManager: cacheManager)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete:[UUID]) {
        for id in idsToDelete {
            Task {
                if let parent = viewModel.chatModel.modelController.cachedPlaceResult(for: id, cacheManager: cacheManager), let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await viewModel.removeCachedResults(group: "Place", identity: fsqID, cacheManager: cacheManager)
                }
            }
        }
    }
}

struct SavedListToolbarView: View {
    @Environment(\.openWindow) private var openWindow
    
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
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
        
        if let savedResult = viewModel.chatModel.modelController.selectedSavedResult  {
            Button(action: {
                Task {
                    do {
                        try await viewModel.removeSelectedItem(selectedSavedResult: savedResult, cacheManager: cacheManager)
                    } catch {
                        viewModel.chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
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
