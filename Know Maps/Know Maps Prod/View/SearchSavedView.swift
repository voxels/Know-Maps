import SwiftUI

struct SearchSavedView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var columnVisibility: NavigationSplitViewVisibility
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var settingsPresented: Bool
    @State private var showNavigationLocationSheet:Bool = false
    @State private var searchText:String = ""

    var body: some View {
        SavedListView(chatModel: chatModel, contentViewDetail: $contentViewDetail, preferredColumn: $preferredColumn)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    SavedListToolbarView(
                        chatModel: chatModel,
                        settingsPresented: $settingsPresented, contentViewDetail: $contentViewDetail, columnVisibility: $columnVisibility, showNavigationLocationSheet: $showNavigationLocationSheet)
                    
                }
            }
            .sheet(isPresented:$showNavigationLocationSheet) {
                VStack {
                    HStack {
                        Button(action: {
                            showNavigationLocationSheet.toggle()
                        }, label: {
                            Label("Done", systemImage: "chevron.backward").labelStyle(.iconOnly)
                        })
                        
                        TextField("New York, NY", text: $searchText)
                            .padding()
                            .onSubmit {
                                search()
                            }
                        
                        Button("Current Location", systemImage:"location") {
                            Task {
                                do {
                                    if let currentLocationName = try await chatModel.currentLocationName() {
                                        try await chatModel.didSearch(caption:currentLocationName, selectedDestinationChatResultID:nil, intent:.Location)
                                    } else {
                                        showNavigationLocationSheet.toggle()
                                    }
                                } catch {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }.labelStyle(.iconOnly)
                        
                        if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                           let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                        {
                            
                            let isSaved = chatModel.cachedLocation(contains:parent.locationName)
                            if isSaved {
                                Button("Delete", systemImage:"minus.circle") {
                                    if let location = parent.location, let cachedLocationResults = chatModel.cachedResults(for: "Location", identity:chatModel.cachedLocationIdentity(for: location)) {
                                        Task {
                                            for cachedLocationResult in cachedLocationResults {
                                                try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                            }
                                            try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }
                            } else {
                                Button("Save", systemImage:"square.and.arrow.down") {
                                    Task{
                                        if let location = parent.location {
                                            var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:chatHost.section(place: parent.locationName).rawValue)
                                            let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                            userRecord.setRecordId(to:record)
                                            await chatModel.appendCachedLocation(with: userRecord)
                                            try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }.labelStyle(.iconOnly)
                            }
                        }
                    }.padding()
                    NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                }
            }
    }
    func search() {
        if !searchText.isEmpty {
            Task {
                do {
                    try await chatModel.didSearch(caption:searchText, selectedDestinationChatResultID:nil, intent:.Location)
                    if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                       let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                    {
                        
                        Task{
                            if let location = parent.location {
                                var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:chatHost.section(place: parent.locationName).rawValue)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                userRecord.setRecordId(to:record)
                                await chatModel.appendCachedLocation(with: userRecord)
                                try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                            }
                        }
                    }
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }
    }
}

struct AddPromptView: View {

    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var sectionSelection: String
    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        TabView(selection: $sectionSelection) {
            SearchTasteView(model: chatModel)
                .tag("Feature")
                .tabItem {
                    Label("Feature", systemImage: "heart")
                }
            SearchCategoryView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                .tag("Industry")
                .tabItem {
                    Label("Industry", systemImage: "building")
                }
            SearchPlacesView(model: chatModel)
                .tag("Place")
                .tabItem {
                    Label("Place", systemImage: "mappin")
                }
        }
    }
}

struct AddPromptToolbarView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var sectionSelection: String
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var columnVisibility:NavigationSplitViewVisibility
    
    var body: some View {
        if sectionSelection == "Industry",
           let parentID = chatModel.selectedCategoryResult,
           let parent = chatModel.categoricalResult(for: parentID) {
            if chatModel.cachedCategories(contains: parent.parentCategory) {
                Button(action: removeCategory(parent: parent)) {
                    Label("Delete", systemImage: "minus.cicle")
                }
                .labelStyle(.iconOnly)
                .padding()
            } else {
                Button(action: addCategory(parent: parent)) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.iconOnly)
                .padding()
            }
        }
        
        if sectionSelection == "Feature",
           let parentID = chatModel.selectedTasteCategoryResult,
           let parent = chatModel.tasteResult(for: parentID) {
            let isSaved = chatModel.cachedTastes(contains: parent.parentCategory)
            if isSaved {
                Button(action: removeTaste(parent: parent)) {
                    Label("Delete", systemImage: "minus.circle")
                }
            } else {
                Button(action: addTaste(parent: parent)) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
        }
        
        Button(action: {
            columnVisibility = .all
        }) {
            Label("Done", systemImage: "checkmark.circle")
        }
    }
    
    private func removeCategory(parent: CategoryResult) -> () -> Void {
        return {
            guard let cachedResults = chatModel.cachedResults(for: "Category", identity: parent.parentCategory) else { return }
            Task {
                for result in cachedResults {
                    try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                }
                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
            }
        }
    }
    
    private func addCategory(parent: CategoryResult) -> () -> Void {
        return {
            Task {
                var userRecord = UserCachedRecord(recordId: "", group: "Category", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: parent.list, section: parent.section.rawValue)
                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                userRecord.setRecordId(to: record)
                await chatModel.appendCachedCategory(with: userRecord)
                await chatModel.refreshCachedResults()
            }
        }
    }
    
    private func removeTaste(parent: CategoryResult) -> () -> Void {
        return {
            guard let cachedResults = chatModel.cachedResults(for: "Taste", identity: parent.parentCategory) else { return }
            for result in cachedResults {
                Task {
                    try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                }
            }
        }
    }
    
    private func addTaste(parent: CategoryResult) -> () -> Void {
        return {
            Task {
                var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: parent.list, section: parent.section.rawValue)
                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                userRecord.setRecordId(to: record)
                await chatModel.appendCachedTaste(with: userRecord)
                await chatModel.refreshCachedResults()
            }
        }
    }
}

struct SavedListView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @State private var selectedResult:CategoryResult.ID?
    var body: some View {
        List(selection: $selectedResult) {
            ForEach(chatModel.allCachedResults, id: \.id) { parent in
                if parent.children.isEmpty {
                    Text(parent.parentCategory)
                } else {
                    DisclosureGroup(isExpanded: Binding(
                        get: { parent.isExpanded },
                        set: { parent.isExpanded = $0 }
                    )) {
                        ForEach(parent.children, id: \.id) { child in
                            Text(child.parentCategory)
                        }
                    } label: {
                        Text(parent.parentCategory)
                    }
                    .disclosureGroupStyle(.automatic)
                }
            }
            .onDelete(perform: deleteItem)
        }
        .onChange(of:selectedResult) { oldValue, newValue in
            guard let newValue = newValue else {
                preferredColumn = .sidebar
                return
            }
            
            if let listResult = chatModel.cachedListResults.first(where: { $0.id == newValue }){
                preferredColumn = .sidebar
                listResult.isExpanded.toggle()
            } else {
                preferredColumn = .detail
                chatModel.selectedSavedResult = newValue
            }
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
    
    private func deleteItem(at offsets: IndexSet) {
        removeSelectedItem()
    }
    
    private func removeSelectedItem() {
        guard let parentID = chatModel.selectedSavedResult,
              let parent = chatModel.allCachedResults.first(where: { $0.id == parentID }) else { return }
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await removeCachedResults(group: "Category", identity: parent.parentCategory)
                }
                group.addTask {
                    await removeCachedResults(group: "Taste", identity: parent.parentCategory)
                }
                group.addTask {
                    await removeCachedResults(group: "Place", identity: parent.parentCategory)
                }
                group.addTask {
                    await removeCachedResults(group: "List", identity: parent.parentCategory)
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
    @Binding public var columnVisibility:NavigationSplitViewVisibility
    @Binding public var showNavigationLocationSheet:Bool

    var body: some View {
        
        
        if contentViewDetail == .places {
            Button(action: {
                columnVisibility = .detailOnly
                contentViewDetail = .add
            }) {
                Label("Add Prompt", systemImage: "plus.circle")
            }
        }
        
        if let selectedSavedResult = chatModel.selectedSavedResult, let categoricalResult = chatModel.allCachedResults.first(where: { result in
            result.id == selectedSavedResult
        }), PersonalizedSearchSection(rawValue: categoricalResult.parentCategory) == nil {
            Button(action: removeSelectedItem) {
                Label("Delete", systemImage: "minus.circle")
            }
        }
        
        Button("Search Location", systemImage:"location.magnifyingglass") {
            chatModel.locationSearchText.removeAll()
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
    
    private func removeSelectedItem() {
        guard let parentID = chatModel.selectedSavedResult,
              let parent = chatModel.allCachedResults.first(where: { $0.id == parentID }) else { return }
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await removeCachedResults(group: "Category", identity: parent.parentCategory)
                }
                group.addTask {
                    await removeCachedResults(group: "Taste", identity: parent.parentCategory)
                }
                group.addTask {
                    await removeCachedResults(group: "Place", identity: parent.parentCategory)
                }
                group.addTask {
                    await removeCachedResults(group: "List", identity: parent.parentCategory)
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
