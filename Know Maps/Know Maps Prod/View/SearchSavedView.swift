import SwiftUI

struct SearchSavedView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    
    @State private var showPopover: Bool = false
    @State private var sectionSelection: String = "Category"
    
    var body: some View {
        if showPopover {
            Section {
                TabView(selection: $sectionSelection) {
                    SearchCategoryView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                        .tag("Category")
                        .tabItem {
                            Label("Category", systemImage: "folder")
                        }
                    
                    SearchTasteView(model: chatModel)
                        .tag("Taste")
                        .tabItem {
                            Label("Taste", systemImage: "heart")
                        }
                    SearchEditView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                        .tag("AI")
                        .tabItem {
                            Label("AI", systemImage: "atom")
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Done", systemImage: "plus") {
                        showPopover = false
                    }.labelStyle(.titleOnly).padding(16)
                }
            }
        } else {
            Section {
                List(chatModel.allCachedResults, children: \.children, selection: $chatModel.selectedSavedResult) { parent in
                    HStack {
                        if chatModel.cloudCache.hasPrivateCloudAccess {
                            ZStack {
                                Capsule()
#if os(macOS)
                                    .foregroundStyle(.background)
                                    .frame(width: 44, height:44)
#else
                                    .foregroundColor(Color(uiColor: .systemFill))
                                    .frame(width: 44, height:44).padding(8)
#endif
                                Label("Save", systemImage: "minus")
                                    .labelStyle(.iconOnly)
                            }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                            .onTapGesture {
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
                        Text("\(parent.parentCategory)")
                        Spacer()
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
                }.task {
                    Task {
                        do {
                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }.toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    HStack {
                        Spacer()
                        Button("Add", systemImage: "plus") {
                            showPopover = true
                        }.labelStyle(.iconOnly).padding()
                        Spacer()
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task {
                                do {
                                    try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                } catch {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }.labelStyle(.iconOnly).padding()
                        Spacer()
                    }
                }
            }
        }
    }
}
