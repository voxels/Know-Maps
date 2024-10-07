import SwiftUI

struct SearchSavedView: View {
    @ObservedObject public var viewModel: SearchSavedViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var contentViewDetail: ContentDetailView
    @Binding public var addItemSection: Int
    @Binding public var settingsPresented: Bool
    @State private var showNavigationLocationSheet: Bool = false
    @State private var searchText: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            SavedListView(viewModel:viewModel, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, preferredColumn: $preferredColumn)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        SavedListToolbarView(
                            viewModel: viewModel,
                            settingsPresented: $settingsPresented,
                            contentViewDetail: $contentViewDetail,
                            preferredColumn: $preferredColumn,
                            showNavigationLocationSheet: $showNavigationLocationSheet
                        )
                    }
                }
                .sheet(isPresented: $showNavigationLocationSheet) {
                    VStack {
                        // Sheet content
                    }
                }
        }
    }
    
    func search() {
        if !searchText.isEmpty {
            Task {
                await viewModel.search(caption: searchText, selectedDestinationChatResultID: nil)
            }
        }
    }
}

struct AddPromptView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        TabView(selection: $addItemSection) {
            SearchCategoryView(chatModel: chatModel, locationProvider: locationProvider)
                .tag(0)
                .tabItem {
                    Label("Type", systemImage: "building")
                }
            
            SearchTasteView(chatModel: chatModel)
                .tag(1)
                .tabItem {
                    Label("Item", systemImage: "heart")
                }
            
            SearchPlacesView(chatModel: chatModel)
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
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var preferredColumn:NavigationSplitViewColumn
    
    var body: some View {
        if addItemSection == 0,
           let parentID = viewModel.chatModel.selectedCategoryResult,
           let parent = viewModel.chatModel.industryCategoryResult(for: parentID) {
            let isSaved = viewModel.chatModel.cacheManager.cachedCategories(contains: parent.parentCategory)
            if isSaved {
                Button(action:{
                    Task {
                        await viewModel.removeCategory(parent: parent)
                    }
                }) {
                    Label("Delete", systemImage: "minus.cicle")
                }
                .labelStyle(.titleAndIcon)
            } else {
                Button(action: {
                    Task {
                        await viewModel.addCategory(parent: parent)
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                
            }
        } else if addItemSection == 1,
                  let parentID = viewModel.chatModel.selectedTasteCategoryResult,
                  let parent = viewModel.chatModel.tasteCategoryResult(for: parentID) {
            let isSaved = viewModel.chatModel.cacheManager.cachedTastes(contains: parent.parentCategory)
            if isSaved {
                Button(action: {
                    Task {
                        await viewModel.removeTaste(parent: parent)
                    }
                }) {
                    Label("Delete", systemImage: "minus.circle")
                }.labelStyle(.titleAndIcon)
            } else {
                Button(action: {
                    Task {
                        await viewModel.addTaste(parent: parent)
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
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var addItemSection:Int
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @State private var selectedResult:CategoryResult.ID?
    var body: some View {
        List(selection: $selectedResult) {
            Section("Types") {
                if !viewModel.chatModel.cacheManager.cachedIndustryResults.isEmpty {
                    ForEach(viewModel.chatModel.cacheManager.cachedIndustryResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }.onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            viewModel.chatModel.cacheManager.cachedIndustryResults[index].id
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
                if !viewModel.chatModel.cacheManager.cachedTasteResults.isEmpty {
                    ForEach(viewModel.chatModel.cacheManager.cachedTasteResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            viewModel.chatModel.cacheManager.cachedTasteResults[index].id
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
                if !viewModel.chatModel.cacheManager.cachedPlaceResults.isEmpty {
                    ForEach(viewModel.chatModel.cacheManager.cachedPlaceResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete{ indexSet in
                        let idsToDelete = indexSet.compactMap { index in
                            viewModel.chatModel.cacheManager.cachedPlaceResults[index].id
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
                ForEach(viewModel.chatModel.cacheManager.cachedDefaultResults, id:\.id) {
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
            viewModel.chatModel.selectedSavedResult = newValue
        }
        .listStyle(.sidebar)
        .refreshable {
            Task {
                do {
                    try await viewModel.chatModel.cacheManager.refreshCache()
                } catch {
                    viewModel.chatModel.analyticsManager.trackError(error:error, additionalInfo: nil)
                }
            }
        }
    }
    
    func removeSelectedItem() async throws {
        if let selectedSavedResult = viewModel.chatModel.selectedSavedResult, let selectedTasteItem = viewModel.chatModel.cachedTasteResult(for: selectedSavedResult) {
            let idsToDelete: [UUID] = [selectedTasteItem.id]
            deleteTasteItem(at: idsToDelete)
        } else if let selectedSavedResult = viewModel.chatModel.selectedSavedResult, let selectedCategoryItem = viewModel.chatModel.cachedCategoricalResult(for: selectedSavedResult){
            let idsToDelete: [UUID] = [selectedCategoryItem.id]
            deleteCategoryItem(at: idsToDelete)
        } else if let selectedSavedResult = viewModel.chatModel.selectedSavedResult, let selectedPlaceItem = viewModel.chatModel.cachedPlaceResult(for: selectedSavedResult) {
            let idsToDelete: [UUID] = [selectedPlaceItem.id]
            deletePlaceItem(at: idsToDelete)
        }
    }
    
    func deleteTasteItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = viewModel.chatModel.cachedTasteResult(for: id) {
                    await viewModel.removeCachedResults(group: "Taste", identity: parent.parentCategory)
                }
            }
        }
    }
    
    
    func deleteCategoryItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = viewModel.chatModel.cachedCategoricalResult(for: id) {
                    await viewModel.removeCachedResults(group: "Category", identity: parent.parentCategory)
                }
            }
        }
    }
    
    func deletePlaceItem(at idsToDelete:[UUID]) {
        for id in idsToDelete {
            Task {
                if let parent = viewModel.chatModel.cachedPlaceResult(for: id), let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await viewModel.removeCachedResults(group: "Place", identity: fsqID)
                }
            }
        }
    }
}

struct SavedListToolbarView: View {
    @Environment(\.openWindow) private var openWindow
    
    @ObservedObject public var viewModel: SearchSavedViewModel
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
        
        if let savedResult = viewModel.chatModel.selectedSavedResult  {
            Button(action: {
                Task {
                    do {
                        try await viewModel.removeSelectedItem(selectedSavedResult: savedResult)
                    } catch {
                        viewModel.chatModel.analyticsManager.trackError(error:error, additionalInfo: nil)
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
