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
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 0
        return retval
    }
    
    var body: some View {
            VStack{
                Spacer()
                    Text("Search Radius (in kilometers)")
                    Slider(value: $distanceFilterValue,in:5...100, step:5)
                    {
                        Text("Kilometers")
                    } minimumValueLabel: {
                        Text("5")
                    } maximumValueLabel: {
                        Text("100")
                    } onEditingChanged: { changed in
                        filters["distance"] = distanceFilterValue * 1000
                    }.padding()
                Text("\(FiltersView.formatter.string(from:NSNumber(value:distanceFilterValue)) ?? "5") kilometers")
                Spacer()
                HStack {
                    Button(action: {
                        if let lastIntent = modelController.queryParametersHistory.last?.queryIntents.last {
                            Task(priority:.userInitiated) {
                                await modelController.resetPlaceModel()
                                await searchSavedViewModel.search(caption: lastIntent.caption, selectedDestinationChatResultID: lastIntent.selectedDestinationLocationID, intent: .Search, filters: searchSavedViewModel.filters, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController)
                            }
                        }                        
                        showFiltersPopover.toggle()
                    }) {
                        Label("Apply Filters", systemImage: "line.3.horizontal.decrease.circle.fill")
                    }
                }
                Spacer()
            }
            .task {
                if let distance = filters["distance"] as? Double {
                    distanceFilterValue = distance
                } else {
                    distanceFilterValue = 20
                }
            }
    }
}
