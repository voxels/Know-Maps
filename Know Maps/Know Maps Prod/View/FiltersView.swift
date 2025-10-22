//
//  FiltersView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/11/24.
//

import SwiftUI

struct FiltersView: View {
    @Environment(\.dismiss) var dismiss
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var filters:[String:Any]
    @Binding public var distanceFilterValue:Double

    @State private var ratingFilterValue:Double = 0
    @State private var kilometers:Float = 0
    @State private var openNowFilterValue:Bool = false
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 0
        return retval
    }
    
    var body: some View {
        VStack(alignment: .leading){
            HStack(spacing:8) {
                Slider(value: $distanceFilterValue,in:0...50, step:1)
                {
                    Text("Kilometers")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("50")
                } onEditingChanged: { changed in
                    let clampedValue = max(distanceFilterValue, 0.5)
                    if changed {
                        // While dragging: update local display only
                        kilometers = Float(clampedValue)
                    } else {
                        // When editing finishes: persist to filters and apply
                        filters["distance"] = clampedValue
                        kilometers = Float(clampedValue)
                        applyFilters()
                    }
                }
                Text(" (\(FiltersView.formatter.string(from:NSNumber(value:distanceFilterValue)) ?? "1") kilometers)")
            }
            .padding()
            Divider()
            //                Toggle("Open Now", isOn: $openNowFilterValue)
            //                    .padding()
            //                Divider()
        }
        .onChange(of:openNowFilterValue) { _, newValue in
            if newValue {
                filters["open_now"] = newValue
                applyFilters()
            }
        }
        .task {
            if let distance = filters["distance"] as? Double {
                distanceFilterValue = distance
            } else {
                distanceFilterValue = 20
            }
            kilometers = Float(distanceFilterValue)
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
    
    func applyFilters() {
        if let lastIntent = modelController.queryParametersHistory.last?.queryIntents.last {
            let selectedDestination = modelController.selectedDestinationLocationChatResult
            modelController.isRefreshingPlaces = true
            Task(priority:.userInitiated) {
                do {
                    try await modelController.resetPlaceModel()
                } catch {
                    modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                }
                await searchSavedViewModel.search(caption: lastIntent.caption, selectedDestinationChatResult: selectedDestination, intent: .Search, filters: searchSavedViewModel.filters, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController)
                await MainActor.run {
                    modelController.isRefreshingPlaces = false
                }
            }
        }
    }
}

