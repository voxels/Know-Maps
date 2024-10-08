//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @State private var searchIsPresented = false
    @State private var searchText:String = ""
    
    var body: some View {
        List(chatModel.modelController.filteredLocationResults(cacheManager: cacheManager), selection:$chatModel.modelController.selectedDestinationLocationChatResult) { result in
            let isSaved = cacheManager.cachedLocation(contains:result.locationName)
            HStack {
                if result.id == chatModel.modelController.selectedDestinationLocationChatResult {
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
    }
}
