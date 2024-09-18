//
//  OnboardingTemplateView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/18/24.
//

import SwiftUI

struct OnboardingTemplateView: View {
    @EnvironmentObject public var cloudCache:CloudCache
    @EnvironmentObject public var settingsModel:SettingsModel
    @EnvironmentObject public var featureFlags:FeatureFlags
    
    @Binding public var selectedTab:String
    @Binding public var showOnboarding:Bool
    @Binding public var isOnboarded:Bool
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var searchIsPresented:Bool = false

    var body: some View {
        VStack(alignment:.leading) {
            Text("Know Maps is an app that helps you find nearby places to go to.")
                .font(.headline)
                .padding()
            VStack(alignment: .leading) {
                Text("1. Use the search bar to find the things your like.")
                Text("2. Click on the plus button to save it.")
                Text("3. Search for and save as many items as you wish, then tap the \"Done\" button")
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 24)

            Section(header: Text("Search Results")) {
                List(chatModel.tasteResults, selection: $chatModel.selectedTasteCategoryResult) { result in
                    HStack {
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
                            let isSaved = chatModel.cachedTastes(contains: result.parentCategory)
                            Label("Save", systemImage:isSaved ? "minus" : "plus").labelStyle(.iconOnly)
                        }
                        .onTapGesture {
                            let isSaved = chatModel.cachedTastes(contains: result.parentCategory)
                            if isSaved {
                                if let cachedTasteResults = chatModel.cachedTasteResults(for: "Taste", identity: result.parentCategory) {
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
                                Task {
                                    do {
                                        var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: result.parentCategory, title: result.parentCategory, icons: "", list: nil)
                                        let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                        if let resultName = record.saveResults.keys.first?.recordName {
                                            userRecord.setRecordId(to:resultName)
                                        }
                                        chatModel.appendCachedTaste(with: userRecord)
                                    } catch {
                                        chatModel.analytics?.track(name: "error \(error)")
                                        print(error)
                                    }
                                }
                            }
                        }
                        Text(result.parentCategory)
                    }
                }
                .searchable(text: $chatModel.locationSearchText, isPresented:$searchIsPresented, placement:.automatic, prompt:"Search for food, drinks, coffee, shops, arts, outdoor sights, or a place name")
                .help(Text("Search for food, drinks, coffee, shops, arts, outdoor sights, or a place names"))
                .onSubmit(of: .search, {
                    if let location = locationProvider.currentLocation() {
                        Task {
                            do {
                                if let name = try await chatModel.currentLocationName() {
                                    chatModel.currentLocationResult.replaceLocation(with: location, name: name)
                                    if chatModel.selectedSourceLocationChatResult == nil, chatModel.currentLocationResult.location != nil {
                                        chatModel.selectedSourceLocationChatResult = chatModel.currentLocationResult.id
                                    }
                                    try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:chatModel.currentLocationResult.id, intent:.AutocompleteTastes)
                                }
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    }
                })
            }.help(Text("To get started, please search for food, drinks, coffee, shops, arts, outdoor sights, or even a place nearby that you like."))
                .padding()
        }.toolbar {
            ToolbarItem(placement:.confirmationAction) {
                Button {
                    isOnboarded = true
                    showOnboarding = false
                } label: {
                    Text("Done")
                }
            }
        }
    }
}


