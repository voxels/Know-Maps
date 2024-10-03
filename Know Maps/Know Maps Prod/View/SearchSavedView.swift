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
        GeometryReader { geometry in
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
                                .onSubmit {
                                    search()
                                }
                                .textFieldStyle(.roundedBorder)
                            
                            if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                               let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                            {
                                
                                let isSaved = chatModel.cachedLocation(contains:parent.locationName)
                                if isSaved {
                                    Button("Delete", systemImage:"minus.circle") {
                                        if let location = parent.location, let cachedLocationResults = chatModel.cachedResults(for: "Location", identity:chatModel.cachedLocationIdentity(for: location)), let cachedLocationResult = cachedLocationResults.first {
                                            Task {
                                                
                                                try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                                
                                                try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                            }
                                        }
                                    }.labelStyle(.iconOnly)
                                        .padding()
                                } else {
                                    Button("Save", systemImage:"square.and.arrow.down") {
                                        Task{
                                            if let location = parent.location {
                                                var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:"none")
                                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                                userRecord.setRecordId(to:record)
                                                try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                            }
                                        }
                                    }.labelStyle(.titleAndIcon)
                                }
                            } else if let parent = chatModel.locationResults.first(where: {$0.locationName == searchText}) {
                                Button("Save", systemImage:"square.and.arrow.down") {
                                    Task{
                                        if let location = parent.location {
                                            var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list:"Places", section:"none")
                                            let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                            userRecord.setRecordId(to:record)
                                            try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }.labelStyle(.titleAndIcon)
                            }
                        }.padding()
                        NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
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
            Section("Lists") {
                ForEach(chatModel.cachedListResults, id:\.id) { parent in
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
                .onDelete(perform: deleteListItem)
            }
            
            
            Section("Features") {
                ForEach(chatModel.cachedTasteResults, id:\.id) { parent in
                    Text(parent.parentCategory)
                }
                .onDelete(perform: deleteTasteItem)
            }
            
            Section("Industries") {
                ForEach(chatModel.cachedCategoryResults, id:\.id) { parent in
                    Text(parent.parentCategory)
                }
                .onDelete(perform: deleteCategoryItem)
            }
            
            Section("Mood") {
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
    
    private func deleteListItem(at offsets: IndexSet) {
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
    
    private func deleteTasteItem(at offsets: IndexSet) {
        let idsToDelete = offsets.map { chatModel.cachedListResults[$0].id }
        
        // Loop through the IDs and delete each one
        for id in idsToDelete {
            Task {
                if let parent = chatModel.cachedListResult(for: id) {
                    await removeCachedResults(group: "List", identity: parent.parentCategory)
                }
                
                if let parent = chatModel.cachedPlaceResult(for: id) {
                    await removeCachedResults(group: "Place", identity: parent.parentCategory)
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
            deleteCategoryItem(at: idsToDelete)
        }
        
        try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
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
                
                if let parent = chatModel.cachedPlaceResult(for: id) {
                    await removeCachedResults(group: "Place", identity: parent.parentCategory)
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
                if let parent = chatModel.cachedPlaceResult(for: id) {
                    await removeCachedResults(group: "Place", identity: parent.parentCategory)
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
