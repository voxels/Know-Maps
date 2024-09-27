import SwiftUI

struct SearchSavedView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var columnVisibility: NavigationSplitViewVisibility
    @Binding public var contentViewDetail:ContentDetailView
    @State private var showPopover: Bool = false
    @State private var sectionSelection: String = "Industry"

    var body: some View {
        if showPopover {
            PopoverContentView(
                chatHost: chatHost,
                chatModel: chatModel,
                locationProvider: locationProvider,
                sectionSelection: $sectionSelection, contentViewDetail: $contentViewDetail
            )
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    PopoverToolbarView(
                        chatModel: chatModel,
                        sectionSelection: $sectionSelection,
                        showPopover: $showPopover, contentViewDetail: $contentViewDetail
                    )
                }
            }
        } else {
            Section {
                SavedListView(chatModel: chatModel, contentViewDetail: $contentViewDetail)
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    SavedListToolbarView(
                        chatModel: chatModel,
                        showPopover: $showPopover,
                        columnVisibility: $columnVisibility
                    )
                }
            }
        }
    }
}

struct PopoverContentView: View {
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var sectionSelection: String
    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        Section {
            TabView(selection: $sectionSelection) {
                SearchCategoryView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                    .tag("Industry")
                    .tabItem {
                        Label("Industry", systemImage: "building")
                    }
                    .onAppear() {
                        contentViewDetail = .places
                    }
                SearchTasteView(model: chatModel)
                    .tag("Taste")
                    .tabItem {
                        Label("Taste", systemImage: "heart")
                    }
                    .onAppear() {
                        contentViewDetail = .places
                    }

                SearchPlacesView(model: chatModel)
                    .tag("Place")
                    .tabItem {
                        Label("Place", systemImage: "mappin")
                    }
                    .onAppear() {
                        contentViewDetail = .places
                    }
                SearchEditView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, contentViewDetail: $contentViewDetail)
                    .tag("AI")
                    .tabItem {
                        Label("AI", systemImage: "atom")
                    }
                    .onAppear() {
                        contentViewDetail = .lists
                    }
            }
        }
    }
}

struct PopoverToolbarView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var sectionSelection: String
    @Binding public var showPopover: Bool
    @Binding public var contentViewDetail:ContentDetailView

    var body: some View {
            if sectionSelection == "Industry",
               let parentID = chatModel.selectedCategoryResult,
               let parent = chatModel.categoricalResult(for: parentID) {
                if chatModel.cachedCategories(contains: parent.parentCategory) {
                    Button(action: removeCategory(parent: parent)) {
                        Label("Remove", systemImage: "minus")
                    }
                    .labelStyle(.iconOnly)
                    .padding()
                } else {
                    Button(action: addCategory(parent: parent)) {
                        Label("Add", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .padding()
                }
            }
            
            if sectionSelection == "Taste",
               let parentID = chatModel.selectedTasteCategoryResult,
               let parent = chatModel.tasteResult(for: parentID) {
                let isSaved = chatModel.cachedTastes(contains: parent.parentCategory)
                if isSaved {
                    Button(action: removeTaste(parent: parent)) {
                        Label("Remove", systemImage: "minus")
                    }
                } else {
                    Button(action: addTaste(parent: parent)) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            
            Button(action: {
                chatModel.refreshCachedResults()
                contentViewDetail = .places
                showPopover = false
            }) {
                Label("Done", systemImage: "checkmark")
            }
            .labelStyle(.titleOnly)
            .padding()
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
                var userRecord = UserCachedRecord(recordId: "", group: "Category", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                userRecord.setRecordId(to: record)
                chatModel.appendCachedCategory(with: userRecord)
                chatModel.refreshCachedResults()
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
                var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                userRecord.setRecordId(to: record)
                chatModel.appendCachedTaste(with: userRecord)
                chatModel.refreshCachedResults()
            }
        }
    }
}

struct SavedListView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        List(selection: $chatModel.selectedSavedResult) {
            ForEach(chatModel.allCachedResults, id: \.id) { parent in
                if parent.children.isEmpty {
                    HStack {
                        Text(parent.parentCategory)
                        Spacer()
                    }
                } else {
                    DisclosureGroup(isExpanded: Binding(
                        get: { parent.isExpanded },
                        set: { parent.isExpanded = $0 }
                    )) {
                        ForEach(parent.children, id: \.id) { child in
                            HStack {
                                Text(child.parentCategory)
                                Spacer()
                            }
                        }
                    } label: {
                        HStack {
                            Text(parent.parentCategory)
                            Spacer()
                        }
                    }
                }
            }
            .onDelete(perform: deleteItem)
        }
        .listStyle(.sidebar)
        .refreshable {
            Task(priority: .userInitiated) {
                do {
                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }
        .task {
            Task(priority: .userInitiated) {
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
        for index in offsets {
            chatModel.allCachedResults.remove(at: index)
        }
    }
}

struct SavedListToolbarView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var showPopover: Bool
    @Binding public var columnVisibility: NavigationSplitViewVisibility

    var body: some View {
            Button(action: {
                chatModel.locationSearchText = ""
                showPopover = true
            }) {
                Label("Add", systemImage: "plus")
            }
            .labelStyle(.iconOnly)
            .padding()
            
            Button(action: removeSelectedItem) {
                Label("Remove", systemImage: "minus")
            }
            
            #if os(visionOS)
            Button(action: {
                columnVisibility = .all
            }) {
                Label("Location", systemImage: "sidebar.left")
            }
            .labelStyle(.iconOnly)
            .padding()
            #endif
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
                       group.addTask { @MainActor in
                           do {
                               try await chatModel.cloudCache.deleteUserCachedRecord(for: result)
                               try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                           } catch {
                               chatModel.analytics?.track(name: "error \(error)")
                               print(error)
                           }
                       }
                   }
               }
           }
       }
}
