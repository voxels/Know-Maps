import SwiftUI

struct SearchSavedView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var addItemSection:Int
    @Binding public var settingsPresented: Bool
    @State private var showNavigationLocationSheet:Bool = false
    @State private var searchText:String = ""
    
    var body: some View {
        GeometryReader { geometry in
            SavedListView(chatModel: chatModel, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, preferredColumn: $preferredColumn)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        SavedListToolbarView(
                            chatModel: chatModel,
                            settingsPresented: $settingsPresented, contentViewDetail: $contentViewDetail, preferredColumn: $preferredColumn, showNavigationLocationSheet: $showNavigationLocationSheet)
                        
                    }
                }
                .sheet(isPresented:$showNavigationLocationSheet) {
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
                        NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                        HStack {
                            if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                               let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                            {
                                let isSaved = chatModel.cachedLocation(contains:parent.locationName)
                                if isSaved {
                                    Button("Delete", systemImage:"minus.circle") {
                                        if let location = parent.location, let cachedLocationResults = chatModel.cachedResults(for: "Location", identity:chatModel.cachedLocationIdentity(for: location)), let cachedLocationResult = cachedLocationResults.first {
                                            Task {
                                                do {
                                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                                    
                                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                                } catch {
                                                    print(error)
                                                    chatModel.analytics?.track(name: "Error deleting location", properties: ["error":error.localizedDescription])
                                                }
                                            }
                                        }
                                    }.labelStyle(.titleAndIcon)
                                        .padding()
                                } else {
                                    Button("Save", systemImage:"square.and.arrow.down") {
                                        Task{
                                            if let location = parent.location {
                                                var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:PersonalizedSearchSection.location.rawValue)
                                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                                userRecord.setRecordId(to:record)
                                                try await Task.sleep(nanoseconds: 1_000_000_000)
                                                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                            }
                                        }
                                    }.labelStyle(.titleAndIcon)
                                        .padding()
                                }
                            } else if let parent = chatModel.locationResults.first(where: {$0.locationName == searchText}) {
                                Button("Save", systemImage:"square.and.arrow.down") {
                                    Task{
                                        if let location = parent.location {
                                            var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:PersonalizedSearchSection.location.rawValue)
                                            let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                            userRecord.setRecordId(to:record)
                                            try await Task.sleep(nanoseconds: 1_000_000_000)
                                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }.labelStyle(.titleAndIcon)
                                    .padding()
                                
                                
                            }
                        }.padding()
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
                do {
                    try await chatModel.didSearch(caption:searchText, selectedDestinationChatResultID:nil, intent:.Location)
                } catch {
                    print(error)
                    chatModel.analytics?.track(name: "error \(error)")
                }
            }
        }
    }
}

struct AddPromptView: View {
    
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        TabView(selection: $addItemSection) {
            SearchCategoryView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                .tag(0)
                .tabItem {
                    Label("Type", systemImage: "building")
                }
            
            SearchTasteView(model: chatModel)
                .tag(1)
                .tabItem {
                    Label("Item", systemImage: "heart")
                }
            
            SearchPlacesView(model: chatModel)
                .tag(2)
                .tabItem {
                    Label("Place", systemImage: "mappin")
                }
        }
    }
}

struct AddPromptToolbarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var addItemSection: Int
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var preferredColumn:NavigationSplitViewColumn
    
    var body: some View {
        if addItemSection == 0,
           let parentID = chatModel.selectedCategoryResult,
           let parent = chatModel.categoricalResult(for: parentID) {
            if chatModel.cachedCategories(contains: parent.parentCategory) {
                Button(action: removeCategory(parent: parent)) {
                    Label("Delete", systemImage: "minus.cicle")
                }
                .labelStyle(.titleAndIcon)
                
            } else {
                Button(action: addCategory(parent: parent)) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                
            }
        } else if addItemSection == 1,
           let parentID = chatModel.selectedTasteCategoryResult,
           let parent = chatModel.tasteResult(for: parentID) {
            let isSaved = chatModel.cachedTastes(contains: parent.parentCategory)
            if isSaved {
                Button(action: removeTaste(parent: parent)) {
                    Label("Delete", systemImage: "minus.circle")
                }.labelStyle(.titleAndIcon)
            } else {
                Button(action: addTaste(parent: parent)) {
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
    
    private func removeCategory(parent: CategoryResult) -> () -> Void {
        return {
            guard let cachedResults = chatModel.cachedResults(for: "Category", identity: parent.parentCategory) else { return }
            Task {
                do {
                    for result in cachedResults {
                        try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                    }
                    
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                } catch {
                    print(error)
                    chatModel.analytics?.track(name: "Error removing category", properties: ["error": error.localizedDescription])
                }
            }
        }
    }
    
    private func addCategory(parent: CategoryResult) -> () -> Void {
        return {
            Task {
                do {
                    var userRecord = UserCachedRecord(recordId: "", group: "Category", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: parent.list, section: parent.section.rawValue)
                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                    userRecord.setRecordId(to: record)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                } catch {
                    print(error)
                    chatModel.analytics?.track(name: "Error adding category", properties: ["error": error.localizedDescription])
                }
            }
        }
    }
    
    private func removeTaste(parent: CategoryResult) -> () -> Void {
        return {
            guard let cachedResults = chatModel.cachedResults(for: "Taste", identity: parent.parentCategory) else { return }
            for result in cachedResults {
                Task {
                    do {
                    try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                    } catch {
                        print(error)
                        chatModel.analytics?.track(name: "Error removing taste", properties: ["error": error.localizedDescription])
                    }
                }
            }
        }
    }
    
    private func addTaste(parent: CategoryResult) -> () -> Void {
        return {
            Task {
                do {
                    var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: parent.list, section: parent.section.rawValue)
                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                    userRecord.setRecordId(to: record)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                } catch {
                    print(error)
                    chatModel.analytics?.track(name: "Error adding taste", properties: ["error": error.localizedDescription])
                }
            }
        }
    }
}

struct SavedListView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var addItemSection:Int
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @State private var selectedResult:CategoryResult.ID?
    var body: some View {
        List(selection: $selectedResult) {
            Section("Types") {
                if !chatModel.cachedCategoryResults.isEmpty {
                    ForEach(chatModel.cachedCategoryResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete(perform: deleteCategoryItem)
                }
                Text("Add a type of place")
                    .onTapGesture {
                        addItemSection = 0
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
            }
            
            Section("Items") {
                if !chatModel.cachedTasteResults.isEmpty {
                    ForEach(chatModel.cachedTasteResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete(perform: deleteTasteItem)
                }
                Text("Add an item")
                    .onTapGesture {
                        addItemSection = 1
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
            }
            
            Section("Places") {
                if !chatModel.cachedPlaceResults.isEmpty {
                    ForEach(chatModel.cachedPlaceResults, id:\.id) { parent in
                        Text(parent.parentCategory)
                    }
                    .onDelete(perform: deletePlaceItem)
                }
                Text("Search for a place")
                    .onTapGesture {
                        addItemSection = 2
                        contentViewDetail = .add
                        preferredColumn = .detail
                    }
            }
            
            Section("Moods") {
                ForEach(chatModel.cachedDefaultResults, id:\.id) {
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
            chatModel.selectedSavedResult = newValue
        }
        .listStyle(.sidebar)
        .refreshable {
            Task {
                do {
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
        chatModel.allCachedResults.move(fromOffsets: source, toOffset: destination)
        print("Moving from: \(source) to: \(destination)")
    }
    
    private func deleteTasteItem(at offsets: IndexSet) {
        let idsToDelete = offsets.map { chatModel.cachedTasteResults[$0].id }
        
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.tasteResult(for: id) {
                    await removeCachedResults(group: "Taste", identity: parent.parentCategory)
                }
            }
        }
    }
    
    private func deletePlaceItem(at offsets: IndexSet) {
        let idsToDelete = offsets.map { chatModel.cachedPlaceResults[$0].id }
        
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedPlaceResult(for: id), let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID  {
                    await removeCachedResults(group: "Place", identity:fsqID)
                }
            }
        }
    }

    
    private func deleteListItem(at offsets: IndexSet) {
        let idsToDelete = offsets.map { chatModel.cachedListResults[$0].id }
        
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedListResult(for: id) {
                    await removeCachedResults(group: "List", identity: parent.parentCategory)
                }
            }
        }
    }
    
    private func deleteCategoryItem(at offsets: IndexSet) {
        let idsToDelete = offsets.map { chatModel.cachedCategoryResults[$0].id }
        
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.categoricalResult(for: id) {
                    await removeCachedResults(group: "Category", identity: parent.parentCategory)
                }
            }
        }
    }
    
    private func removeCachedResults(group: String, identity: String) async {
        if let cachedResults = chatModel.cachedResults(for: group, identity: identity) {
            await withTaskGroup(of: Void.self) { group in
                for result in cachedResults {
                    group.addTask {
                        do {
                            try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                        } catch {
                            await chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }
        }
    }
}

struct SavedListToolbarView: View {
    @Environment(\.openWindow) private var openWindow
    
    @ObservedObject public var chatModel: ChatResultViewModel
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
        
        if let _ = chatModel.selectedSavedResult {
            Button(action: {
                Task {
                    do {
                        try await removeSelectedItem()
                    } catch {
                        print(error)
                        chatModel.analytics?.track(name: "Error removing saved item", properties: ["error": error.localizedDescription])
                    }
                }
            }, label: {
                Label("Delete", systemImage: "minus.circle")
            })
        }
        
        Button("Search Location", systemImage:"location.magnifyingglass") {
            showNavigationLocationSheet.toggle()
        }
        
        /*
         if contentViewDetail == .places{
         Button(action: {
         contentViewDetail = .order
         columnVisibility = .detailOnly
         }, label: {
         Label("Reorder Lists", systemImage: "list.bullet.indent")
         })
         } else if contentViewDetail == .order || contentViewDetail == .add {
         Button(action: {
         contentViewDetail = .places
         columnVisibility = .all
         }, label: {
         Label("Reorder Lists", systemImage: "list.bullet")
         })
         }
         */
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
    
    private func removeSelectedItem() async throws {
        if let selectedSavedResult = chatModel.selectedSavedResult, let selectedListItem = chatModel.cachedListResult(for: selectedSavedResult) {
            let idsToDelete: [UUID] = [selectedListItem.id]
            deleteListItem(at: idsToDelete)
        } else if let selectedSavedResult = chatModel.selectedSavedResult, let selectedTasteItem = chatModel.cachedTasteResult(for: selectedSavedResult) {
            let idsToDelete: [UUID] = [selectedTasteItem.id]
            deleteTasteItem(at: idsToDelete)
        } else if let selectedSavedResult = chatModel.selectedSavedResult, let selectedCategoryItem = chatModel.cachedCategoricalResult(for: selectedSavedResult){
            let idsToDelete: [UUID] = [selectedCategoryItem.id]
            deleteCategoryItem(at: idsToDelete)
        } else if let selectedSavedResult = chatModel.selectedSavedResult, let selectedPlaceItem = chatModel.cachedPlaceResult(for: selectedSavedResult) {
            let idsToDelete: [UUID] = [selectedPlaceItem.id]
            deletePlaceItem(at: idsToDelete)
        }
    }
    
    private func deleteTasteItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedTasteResult(for: id) {
                    await removeCachedResults(group: "Taste", identity: parent.parentCategory)
                }
            }
        }
    }
    
    private func deleteListItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedListResult(for: id) {
                    await removeCachedResults(group: "List", identity: parent.parentCategory)
                }
            }
        }
    }
    
    private func deleteCategoryItem(at idsToDelete: [UUID]) {
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedCategoricalResult(for: id) {
                    await removeCachedResults(group: "Category", identity: parent.parentCategory)
                }
            }
        }
    }
    
    private func deletePlaceItem(at idsToDelete:[UUID]) {
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedPlaceResult(for: id), let fsqID = parent.categoricalChatResults.first?.placeResponse?.fsqID {
                    await removeCachedResults(group: "Place", identity: fsqID)
                }
            }
        }
    }
    
    private func removeCachedResults(group: String, identity: String) async {
        if let cachedResults = chatModel.cachedResults(for: group, identity: identity) {
            await withTaskGroup(of: Void.self) { group in
                for result in cachedResults {
                    group.addTask {
                        do {
                            try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                        } catch {
                            await chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }
        }
    }
}
