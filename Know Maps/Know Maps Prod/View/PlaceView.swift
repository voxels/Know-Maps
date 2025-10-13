//
//  PlaceView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/18/23.
//

import SwiftUI
import MapKit

struct PlaceView: View {
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @ObservedObject public var placeDirectionsViewModel:PlaceDirectionsViewModel
    @State private var tabItem = 0
    public let selectedFoursquareID:String

    var body: some View {
        if let placeChatResult = modelController.placeChatResult(with: selectedFoursquareID) {
            VStack {
                if let detailsResponses = placeChatResult.placeDetailsResponse {
                    Picker("About", selection: $tabItem) {
                        Text("About").tag(0)
                        Text("Directions").tag(1)
                        if let photoResponses = detailsResponses.photoResponses, photoResponses.count > 0 {
                            Text("Photos").tag(2)
                        }
                        if let tipsResponses = detailsResponses.tipsResponses, tipsResponses.count > 0 {
                            Text("Tips").tag(3)
                        }
                    }
                    .pickerStyle(.palette)
                }
                switch tabItem {
                case 0:
                    PlaceAboutView(searchSavedViewModel:$searchSavedViewModel, chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, tabItem: $tabItem)
                        .tabItem {
                            Label("About", systemImage: "target")
                        }
                        .tag("About")
                        .onAppear(perform: {
                            modelController.analyticsManager.track(event:"PlaceAboutView", properties: nil)
                        })
                case 1:
                    PlaceDirectionsView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, model: placeDirectionsViewModel)
                        .tabItem {
                            Label("Directions", systemImage: "map")
                        }
                        .tag("Directions")
                        .onAppear(perform: {
                            modelController.analyticsManager.track(event:"PlaceDirectionsView", properties: nil)
                        })
                case 2:
                    if let detailsResponses = placeChatResult.placeDetailsResponse {
                        if let photoResponses = detailsResponses.photoResponses, photoResponses.count > 0 {
                            PlacePhotosView(chatModel: $chatModel, modelController: $modelController)
                                .tabItem {
                                    Label("Photos", systemImage: "photo.stack")
                                }
                                .tag("Photos")
                                .onAppear(perform: {
                                    modelController.analyticsManager.track(event:"PlacePhotosView", properties: nil)
                                })
                        }
                    }
                case 3:
                    if let detailsResponses = placeChatResult.placeDetailsResponse {
                        if let tipsResponses = detailsResponses.tipsResponses, tipsResponses.count > 0 {
                            PlaceTipsView(chatModel: $chatModel, modelController: $modelController)
                                .tabItem {
                                    Label("Tips", systemImage: "quote.bubble")
                                }
                                .tag("Tips")
                                .onAppear(perform: {
                                    modelController.analyticsManager.track(event:"PlaceTipsView", properties: nil)
                                })
                        }
                    }
                default:
                    EmptyView()
                }
            }
            .navigationTitle(placeChatResult.title)
            .id(placeChatResult.id)
        } else {
            VStack {
                Spacer()
                if let _ = modelController.selectedPlaceFSQID {
                    // We have a target ID but haven't materialized the result yet; show fetch message
                    VStack(spacing: 8) {
                        Text(modelController.fetchMessage)
                            .font(.subheadline)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

