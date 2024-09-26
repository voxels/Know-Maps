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
    @State private var isSaving:Bool = false
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment:.leading, spacing:0) {
                Text("Know Maps is an app that helps you find nearby places to go to.")
                    .font(.headline)
                    .padding(.top, 60)
                if chatModel.locationSearchText.isEmpty {
                    withAnimation {
                        VStack(alignment: .leading) {
                            Text("1. Use the search bar to find the things your like.")
                            Text("2. Click on the plus button to save it.")
                            Text("3. Search for and save as many items as you wish, then tap the \"Done\" button")
                        }
                    }
                }
                TextField("Search for food, drinks, coffee, shops, arts, outdoor sights, or a place name", text: $chatModel.locationSearchText)
                    .onSubmit {
                        if let _ = locationProvider.currentLocation() {
                            Task {
                                do {
                                    try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:chatModel.currentLocationResult.id, intent:.AutocompleteTastes)
                                } catch {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }
                    }.padding(.vertical, 16)
                HStack(spacing:0) {
                    VStack (alignment: .leading, spacing: 0) {
                        Text("Search Results").padding(.vertical,4)
                        List(selection:$chatModel.selectedTasteCategoryResult){
                            ForEach(chatModel.tasteResults) { result in
                                Text(result.parentCategory)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 0){
                        Text("Saved Results").padding(.vertical, 4)
                        if isSaving {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                Spacer()
                            }
                        } else {
                            List(chatModel.cachedTasteResults,selection:$chatModel.selectedTasteCategoryResult) { result in
                                Text(result.parentCategory)
                            }
                        }
                    }
                }
                .onChange(of: chatModel.selectedTasteCategoryResult) { oldValue, newValue in
                    guard let newValue = newValue else { return }
                    if let result = chatModel.cachedTasteResult(for: newValue) {
                        
                        let isSaved = chatModel.cachedTastes(contains: result.parentCategory)
                        if isSaved {
                            if let cachedTasteResults = chatModel.cachedTasteResults(for: "Taste", identity: result.parentCategory) {
                                for cachedTasteResult in cachedTasteResults {
                                    Task(priority: .userInitiated) {
                                        do {
                                            try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                            try await chatModel.refreshCache(cloudCache: cloudCache)
                                        } catch {
                                            chatModel.analytics?.track(name: "error \(error)")
                                            print(error)
                                        }
                                        
                                    }
                                }
                            }
                        }
                    } else if let result = chatModel.tasteChatResult(for: newValue) {
                        Task(priority: .userInitiated) {
                            do {
                                var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: result.title, title:result.title, icons: "", list: nil)
                                userRecord.recordId = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                chatModel.appendCachedTaste(with: userRecord)
                                chatModel.refreshCachedResults()
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    }
                }
                HStack {
                    Button(action:{
                        Task(priority:.userInitiated) { @MainActor in
                            try await chatModel.refreshCache(cloudCache: cloudCache)
                        }
                    }, label:{
                        Label("Store in iCloud", systemImage:"square.and.arrow.up.circle").labelStyle(.titleAndIcon)
                    })
                    .foregroundStyle(.accent)
                    Spacer()
                }.padding()
            }
            .overlay(content: {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isOnboarded = true
                            showOnboarding = false
                        } label: {
                            Text("Done")
                        }.padding()
                    }
                    Spacer()
                }
            })
        }.padding()
    }
}
