import SwiftUI

struct SearchSavedView: View {
    @ObservedObject public var model: ChatResultViewModel
    
    var body: some View {
        Section {
            List {
                ForEach(model.allCachedResults, id: \.self) { parent in
                    HStack {
                        if model.cloudCache.hasPrivateCloudAccess {
                            Label("Is Saved", systemImage: "star.fill").labelStyle(.iconOnly)
                        }
                        
                        Text("\(parent.parentCategory)")
                        Spacer()
                    }
                }
                .onDelete(perform: deleteItems) // Add delete functionality here
            }
            .listStyle(.sidebar)
            .refreshable {
                Task {
                    do {
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .task {
                Task {
                    do {
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
        } footer: {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    do {
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .labelStyle(.iconOnly)
            .padding(16)
        }
    }
    
    // Function to handle deletion
    private func deleteItems(at offsets: IndexSet) {
        offsets.forEach { index in
            let parent = model.allCachedResults[index]
            
            // Perform deletion using your model's methods
            if let cachedCategoricalResults = model.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) {
                for cachedCategoricalResult in cachedCategoricalResults {
                    Task {
                        try await model.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    }
                }
            }
            
            if let cachedTasteResults = model.cachedTasteResults(for: "Taste", identity: parent.parentCategory) {
                for cachedTasteResult in cachedTasteResults {
                    Task {
                        try await model.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    }
                }
            }

            if let cachedPlaceResults = model.cachedPlaceResults(for: "Place", title:parent.parentCategory ) {
                for cachedPlaceResult in cachedPlaceResults {
                    Task {
                        try await model.cloudCache.deleteUserCachedRecord(for: cachedPlaceResult)
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    }
                }
            }

            if let cachedListResults = model.cachedListResults(for: "List", title:parent.parentCategory ) {
                for cachedListResult in cachedListResults {
                    Task {
                        try await model.cloudCache.deleteUserCachedRecord(for: cachedListResult)
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    }
                }
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    return SearchSavedView(model: chatModel)
}
