//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import Segment
import MapKit

public enum ContentDetailView {
    case places
    case order
    case add
}

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif

    @EnvironmentObject public var cloudCache:CloudCache
    @EnvironmentObject public var settingsModel:SettingsModel
    @EnvironmentObject public var featureFlags:FeatureFlags

    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var isOnboarded:Bool
    @Binding public var showOnboarding:Bool

    @State private var selectedItem: String?
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var columnVisibility =
    NavigationSplitViewVisibility.all
    @State private var sectionSelection: String = "Feature"
    @State private var settingsPresented:Bool = false
    @State private var didError = false
    @State private var contentViewDetail:ContentDetailView = .places
    
    var body: some View {
        GeometryReader() { geometry in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SearchView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, columnVisibility: $columnVisibility, contentViewDetail: $contentViewDetail, settingsPresented: $settingsPresented)
#if os(iOS) || os(visionOS)
        .sheet(isPresented: $settingsPresented) {
            SettingsView(chatModel: chatModel, isOnboarded: $isOnboarded, showOnboarding: $showOnboarding)
        }
#endif
            } detail: {
                switch contentViewDetail {
                case .places:
                    PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                        .alert("Unknown Place", isPresented: $didError) {
                            Button(action: {
                                chatModel.selectedPlaceChatResult = nil
                            }, label: {
                                Text("Go Back")
                            })
                        } message: {
                            Text("We don't know much about this place.")
                        }
                case .order:
                    PromptRankingView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, contentViewDetail: $contentViewDetail)
                case .add:
                    HStack {
                        AddPromptView(
                            chatHost: chatHost,
                            chatModel: chatModel,
                            locationProvider: locationProvider,
                            sectionSelection: $sectionSelection, contentViewDetail: $contentViewDetail
                        )
                        .toolbar {
                            ToolbarItemGroup(placement: .automatic) {
                                AddPromptToolbarView(
                                    chatModel: chatModel,
                                    sectionSelection: $sectionSelection,
                                    contentViewDetail: $contentViewDetail, columnVisibility: $columnVisibility
                                )
                            }
                        }
                        .frame(maxWidth:geometry.size.width / 3)
                        PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                            .alert("Unknown Place", isPresented: $didError) {
                                Button(action: {
                                    chatModel.selectedPlaceChatResult = nil
                                }, label: {
                                    Text("Go Back")
                                })
                            } message: {
                                Text("We don't know much about this place.")
                            }
                    }
                }
            }
        }
        .onAppear(perform: {
            chatModel.analytics?.screen(title: "NavigationSplitView")
        })
        .onChange(of: selectedItem, { oldValue, newValue in
            Task {
                try await chatModel.didTapMarker(with: newValue)
            }
        })
        .onChange(of: chatModel.selectedPlaceChatResult, { oldValue, newValue in
            guard let newValue = newValue else {
                
                return
            }
            
            let _ = Task { @MainActor in
                do {
                    if newValue != oldValue, let placeChatResult = chatModel.placeChatResult(for: newValue) {
                        try await chatModel.didTap(placeChatResult: placeChatResult)
                    }
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                    didError.toggle()
                }
            }
        })
        .onChange(of: settingsModel.appleUserId, { oldValue, newValue in
            if !newValue.isEmpty {
                Task { @MainActor in
                    cloudCache.hasPrivateCloudAccess = true
                }
            }
        })
        .onChange(of: columnVisibility) { oldValue, newValue in
            if newValue == .all {
                contentViewDetail = .places
            }
        }
    }
}

