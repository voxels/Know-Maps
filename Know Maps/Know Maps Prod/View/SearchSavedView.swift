import SwiftUI

struct SearchSavedView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var columnVisibility: NavigationSplitViewVisibility
    @State private var showPopover: Bool = false
    @State private var sectionSelection: String = "Industry"
    
    var body: some View {
        if showPopover {
            Section {
                TabView(selection: $sectionSelection) {
                    SearchCategoryView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                        .tag("Industry")
                        .tabItem {
                            Label("Industry", systemImage: "building")
                        }
                    
                    SearchTasteView(model: chatModel)
                        .tag("Taste")
                        .tabItem {
                            Label("Taste", systemImage: "heart")
                        }
                    SearchPlacesView(model:chatModel)
                        .tag("Places")
                        .tabItem {
                            Label("Places", systemImage: "mappin")
                        }
                    SearchEditView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                        .tag("AI")
                        .tabItem {
                            Label("AI", systemImage: "atom")
                        }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement:.topBarTrailing) {
                    
                    if sectionSelection == "Category", let parentID = chatModel.selectedCategoryResult, let parent = chatModel.categoricalResult(for: parentID) {
                        if chatModel.cachedCategories(contains: parent.parentCategory) {
                            Button("Remove", systemImage: "minus") {
                                guard let cachedCategoricalResults =  chatModel.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) else { return }
                                Task {
                                    for cachedCategoricalResult in cachedCategoricalResults {
                                        try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                                    }
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }.labelStyle(.iconOnly).padding()
                        }
                        else {
                            Button("Add", systemImage: "plus") {
                                Task {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Category", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                    userRecord.setRecordId(to:record)
                                    chatModel.appendCachedCategory(with: userRecord)
                                    chatModel.refreshCachedResults()
                                }
                            }.labelStyle(.iconOnly).padding()
                        }
                    }
                    
                    if sectionSelection == "Taste", let parentID = chatModel.selectedTasteCategoryResult, let parent = chatModel.tasteResult(for: parentID) {
                        let isSaved = chatModel.cachedTastes(contains: parent.parentCategory)
                        if isSaved, let cachedTasteResults = chatModel.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                                Button("Remove", systemImage: "minus") {
                                    for cachedTasteResult in cachedTasteResults {
                                        Task {
                                            do {
                                                try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                            } catch {
                                                chatModel.analytics?.track(name: "error \(error)")
                                                print(error)
                                            }
                                        }
                                    }
                                }
                            
                        } else {
                            Button("Add", systemImage: "plus") {
                                Task {
                                    do {
                                        var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                                        let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                        userRecord.setRecordId(to:record)
                                        chatModel.appendCachedTaste(with: userRecord)
                                        chatModel.refreshCachedResults()
                                    } catch {
                                        chatModel.analytics?.track(name: "error \(error)")
                                        print(error)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button("Done", systemImage: "plus") {
                        chatModel.refreshCachedResults()
                        showPopover = false
                    }.labelStyle(.titleOnly).padding()
                }
            }
        } else {
            Section {
                List( selection: $chatModel.selectedSavedResult) {
                    ForEach(chatModel.allCachedResults, id:\.id){ parent in
                        if parent.children.isEmpty {
                            HStack {
                                Text("\(parent.parentCategory)")
                                Spacer()
                            }
                        }
                        else {
                            DisclosureGroup(isExpanded: Binding(
                                get: { parent.isExpanded },
                                set: { parent.isExpanded = $0 }
                            )){
                                ForEach(parent.children, id:\.id) { child in
                                    HStack {
                                        Text("\(child.parentCategory)")
                                        Spacer()
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(parent.parentCategory)")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onMove(perform: moveItem)
                    .onDelete(perform: deleteItem)
                }
                .listStyle(.sidebar)
                .refreshable {
                    Task(priority:.userInitiated) {
                        do {
                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }.task {
                    Task(priority:.userInitiated) {
                        do {
                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }.toolbar {
#if os(macOS)
                ToolbarItemGroup(placement: .automatic) {
                    Button("Add", systemImage: "plus") {
                        chatModel.locationSearchText = ""
                        showPopover = true
                    }.labelStyle(.iconOnly).padding()
                    Button("Remove", systemImage: "minus") {
                        guard let parentID = chatModel.selectedSavedResult, let parent = chatModel.allCachedResults.first(where: { $0.id == parentID }) else { return }
                        if let cachedCategoricalResults = chatModel.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) {
                            for cachedCategoricalResult in cachedCategoricalResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                        
                        if let cachedTasteResults = chatModel.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                            for cachedTasteResult in cachedTasteResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                        
                        if let cachedPlaceResults = chatModel.cachedPlaceResults(for: "Place", title: parent.parentCategory) {
                            for cachedPlaceResult in cachedPlaceResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedPlaceResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                        
                        if let cachedListResults = chatModel.cachedListResults(for: "List", title: parent.parentCategory) {
                            for cachedListResult in cachedListResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedListResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                    }
                }
                
#else
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        chatModel.locationSearchText = ""
                        showPopover = true
                    }.labelStyle(.iconOnly).padding()
                    Button("Remove", systemImage: "minus") {
                        guard let parentID = chatModel.selectedSavedResult, let parent = chatModel.allCachedResults.first(where: { $0.id == parentID }) else { return }
                        if let cachedCategoricalResults = chatModel.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) {
                            for cachedCategoricalResult in cachedCategoricalResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                        
                        if let cachedTasteResults = chatModel.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                            for cachedTasteResult in cachedTasteResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                        
                        if let cachedPlaceResults = chatModel.cachedPlaceResults(for: "Place", title: parent.parentCategory) {
                            for cachedPlaceResult in cachedPlaceResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedPlaceResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                        
                        if let cachedListResults = chatModel.cachedListResults(for: "List", title: parent.parentCategory) {
                            for cachedListResult in cachedListResults {
                                Task {
                                    try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedListResult)
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                }
                            }
                        }
                    }
#if os(visionOS)
                    Button("Location", systemImage: "sidebar.left") {
                        Task {
                            do {
                                //                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                columnVisibility = .all
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    }.labelStyle(.iconOnly).padding()
#endif
                    
                   
                }
#endif
                
            }
        }
    }
    
    // Function to move items in the list
    private func moveItem(from source: IndexSet, to destination: Int) {
        chatModel.allCachedResults.move(fromOffsets: source, toOffset: destination)
    }
    
    // Function to delete items in the list
    private func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let item = chatModel.allCachedResults[index]
            chatModel.allCachedResults.remove(at: index)
            
        }
    }
}
