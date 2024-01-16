//
//  SearchSavedView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchSavedView: View {
    @ObservedObject public var model:ChatResultViewModel
    
    var body: some View {
        Section {
            
            List(model.allCachedResults, children:\.children, selection: $model.selectedSavedResult) { parent in
                HStack {
                    Text("\(parent.parentCategory)")
                    Spacer()
                    if model.cloudCache.hasPrivateCloudAccess {
                        Label("Save", systemImage:"star.fill")
                            .labelStyle(.iconOnly)
                            .onTapGesture {
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
                            }
                    }
                }
            }.refreshable {
                Task {
                    do{
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }.task {
                Task {
                    do{
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
                    do{
                        try await model.refreshCache(cloudCache: model.cloudCache)
                    } catch {
                        model.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }.labelStyle(.iconOnly).padding(16)
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    return SearchSavedView(model: chatModel)
}
