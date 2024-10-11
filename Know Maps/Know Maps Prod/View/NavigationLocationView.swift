//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @State private var searchIsPresented = false
    @State private var searchText:String = ""
    var body: some View {
        List(modelController.filteredLocationResults(cacheManager: cacheManager), selection:$modelController.selectedDestinationLocationChatResult) { result in
            let isSaved = cacheManager.cachedLocation(contains:result.locationName)
            HStack {
                if result.id == modelController.selectedDestinationLocationChatResult {
                    Label(result.locationName, systemImage: "mappin")
                        .tint(.red)
                } else {
                    Label(result.locationName, systemImage: "mappin")
                        .tint(.blue)
                }
                Spacer()
                isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
            }
        }
        .onChange(of: modelController.selectedDestinationLocationChatResult) { oldValue, newValue in
            Task {
                modelController.selectedSavedResult = nil
                await modelController.resetPlaceModel()
            }
        }
    }
}
