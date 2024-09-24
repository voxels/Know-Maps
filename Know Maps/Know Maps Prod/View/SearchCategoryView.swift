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
        List(chatModel.categoryResults, children:\.children, selection:$chatModel.selectedCategoryResult) { parent in
                HStack {
                    if chatModel.cloudCache.hasPrivateCloudAccess {
                        ZStack {
                            Capsule()
    #if os(macOS)
                                .foregroundStyle(.background)
                                .frame(width: 44, height:44)
                                .padding(8)
    #else
                                .foregroundColor(Color(uiColor:.systemFill))
                                .frame(width: 44, height: 44, alignment: .center)
                                .padding(8)
    #endif
                            let isSaved = chatModel.cachedCategories(contains: parent.parentCategory)
                            Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                        }
                        .foregroundStyle(.accent)
                        .onTapGesture {
                            let isSaved = chatModel.cachedCategories(contains: parent.parentCategory)
                            if isSaved {
                                if let cachedCategoricalResults = chatModel.cachedCategoricalResults(for: "Category", identity: parent.parentCategory) {
                                    Task {
                                        for cachedCategoricalResult in cachedCategoricalResults {
                                            try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedCategoricalResult)
                                        }
                                        try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                    }
                                }
                            } else {
                                Task {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Category", identity: parent.parentCategory, title: parent.parentCategory, icons: "", list: nil)
                                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                    userRecord.setRecordId(to:record)
                                    chatModel.appendCachedCategory(with: userRecord)
                                    chatModel.refreshCachedResults()
                                }
                            }
                        }
    #if os(iOS) || os(visionOS)
                                .hoverEffect(.lift)
    #endif

                    }
                    Text("\(parent.parentCategory)")
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
