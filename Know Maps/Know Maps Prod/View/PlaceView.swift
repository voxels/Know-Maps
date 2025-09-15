//
//  PlaceView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/18/23.
//

import SwiftUI
import MapKit

struct PlaceView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @ObservedObject public var placeDirectionsViewModel:PlaceDirectionsViewModel
    @Binding public var addItemSection:Int
    @State private var tabItem = 0
    
    var body: some View {
        if let resultId = modelController.selectedPlaceChatResult, let placeChatResult = modelController.placeChatResult(for: resultId) {
            VStack {
                Picker("", selection: $tabItem) {
                    Text("About").tag(0)
                    Text("Directions").tag(1)
                    if let detailsResponses = placeChatResult.placeDetailsResponse, let photoResponses = detailsResponses.photoResponses, photoResponses.count > 0 {
                        Text("Photos").tag(2)
                    }
                    if let detailsResponses = placeChatResult.placeDetailsResponse, let tipsResponses = detailsResponses.tipsResponses, tipsResponses.count > 0 {
                        Text("Tips").tag(3)
                    }
                }
                .padding()
                .pickerStyle(.palette)
                switch tabItem {
                case 0:
                    PlaceAboutView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, tabItem: $tabItem)
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
                    VStack {
                        Spacer()
                        ContentUnavailableView("No Place Selected", systemImage:"return")
                        Spacer()
                    }
                }
            }
            .navigationTitle(placeChatResult.title)
        } else {
            VStack {
                Spacer()
                ContentUnavailableView("No Place Selected", systemImage:"return")
                Spacer()
            }
        }
    }
}

