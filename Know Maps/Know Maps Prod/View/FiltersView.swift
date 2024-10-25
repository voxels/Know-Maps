//
//  FiltersView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/11/24.
//

import SwiftUI

struct FiltersView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var filters:[String:Any]
    @Binding public var showFiltersPopover:Bool
    @State private var distanceFilterValue:Double = 0
    @State private var ratingFilterValue:Double = 0
    @State private var openNowFilterValue:Bool = false
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 0
        return retval
    }
    
    var body: some View {
            VStack(alignment: .leading){
                Spacer()
                    Text("Search Radius (\(FiltersView.formatter.string(from:NSNumber(value:distanceFilterValue)) ?? "1") kilometers)")
                    .padding()
                    Slider(value: $distanceFilterValue,in:0...50, step:1)
                    {
                        Text("Kilometers")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("50")
                    } onEditingChanged: { changed in
                        filters["distance"] = max(distanceFilterValue, 0.5)
                    }
                    .frame(maxWidth:.infinity)
                    .padding()
                Divider()
//                Text("Minimum rating (\(FiltersView.formatter.string(from:NSNumber(value:ratingFilterValue)) ?? "1") kilometers)")
//                .padding()
//                Slider(value: $ratingFilterValue,in:0...10, step:0.5)
//                {
//                    Text("Kilometers")
//                } minimumValueLabel: {
//                    Text("0")
//                } maximumValueLabel: {
//                    Text("10")
//                } onEditingChanged: { changed in
//                    filters["rating"] = max(ratingFilterValue, 0)
//                }
//                .frame(maxWidth:.infinity)
//                .padding()
//                Divider()
                Toggle("Open Now", isOn: $openNowFilterValue)
                    .padding()
                    .frame(maxWidth:220)
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        if let lastIntent = modelController.queryParametersHistory.last?.queryIntents.last {
                            modelController.isRefreshingPlaces = true
                            modelController.fetchMessage = "Searching for places"
                            Task(priority:.userInitiated) {
                                await modelController.resetPlaceModel()
                                await searchSavedViewModel.search(caption: lastIntent.caption, selectedDestinationChatResultID: lastIntent.selectedDestinationLocationID, intent: .Search, filters: searchSavedViewModel.filters, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController)
                                await MainActor.run {
                                    modelController.isRefreshingPlaces = false
                                }
                            }
                        }                        
                        showFiltersPopover.toggle()
                    }) {
                        Label("Apply Filters", systemImage: "line.3.horizontal.decrease.circle.fill")
                    }.padding()
                }.padding()
            }
            .padding()
            .onChange(of:openNowFilterValue) { _, newValue in
                if newValue {
                    filters["open_now"] = newValue
                }
            }
            .task {
                if let distance = filters["distance"] as? Double {
                    distanceFilterValue = distance
                } else {
                    distanceFilterValue = 20
                }
            }
            .task {
                if let rating = filters["rating"] as? Double {
                    ratingFilterValue = rating
                } else {
                    ratingFilterValue = 0
                }
            }.task {
                if let openNow = filters["open_now"] as? Bool {
                    openNowFilterValue = openNow
                } else {
                    openNowFilterValue = false
                }
            }
    }
}
