//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var model:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider

    var body: some View { 
        Section("Categories") {
            List(model.filteredResults, children:\.children, selection:$model.selectedCategoryResult) { parent in
                Text("\(parent.parentCategory)")
            }
            .onChange(of: model.selectedCategoryResult) { oldValue, newValue in
                if newValue == nil {
                    model.selectedPlaceChatResult = nil
                }
                Task { @MainActor in
                    if let newValue = newValue, let categoricalResult =
                        model.categoricalResult(for: newValue) {
                        model.locationSearchText = model.chatResult(for: newValue)?.title ?? model.locationSearchText
                        await chatHost.didTap(chatResult: categoricalResult)
                    }
                }
            }
        }
    }
}

#Preview {

    let locationProvider = LocationProvider()
    let chatHost = AssistiveChatHost()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)

    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    return SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
}
