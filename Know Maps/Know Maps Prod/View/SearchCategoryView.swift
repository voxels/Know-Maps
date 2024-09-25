//
//  SearchCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchCategoryView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var didError = false
    
    var body: some View {
        List( selection:$chatModel.selectedCategoryResult) {
            ForEach(chatModel.categoryResults, id:\.id){ parent in
                DisclosureGroup(isExpanded: Binding(
                    get: { parent.isExpanded },
                    set: { parent.isExpanded = $0 }
                )){
                    ForEach(parent.children, id:\.id) { child in
                        let isSaved = chatModel.cachedCategories(contains: child.parentCategory)
                        HStack {
                            Text("\(child.parentCategory)")
                            Spacer()
                            isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
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
        .listStyle(.sidebar)
        .refreshable {
            chatModel.isRefreshingCache = false
            Task {
                do{
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
                    print(error)
                    chatModel.analytics?.track(name: "error \(error)")
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
    
    return SearchCategoryView(chatHost: AssistiveChatHost(), chatModel: chatModel, locationProvider: locationProvider)
}
