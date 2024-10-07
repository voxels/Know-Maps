//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI

struct NavigationLocationView: View {
    @State private var searchIsPresented = false
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var searchText:String = ""
    
    var body: some View {
        List(chatModel.filteredLocationResults, selection:$chatModel.selectedDestinationLocationChatResult) { result in
            let isSaved = chatModel.cacheManager.cachedLocation(contains:result.locationName)
            HStack {
                if result.id == chatModel.selectedDestinationLocationChatResult {
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
