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
        List(model.filteredResults, selection:$model.selectedCategoryChatResult) { result in
            Section {
                ForEach(result.categoricalChatResults) { chatResult in
                    Label(chatResult.title, systemImage:"folder").listItemTint(.white)
                }
            } header: {
                Text(result.parentCategory)
            }
        }
        .searchable(text: $model.locationSearchText)
        .onChange(of: model.selectedCategoryChatResult) { oldValue, newValue in
            if newValue == nil {
                model.selectedPlaceChatResult = nil
            }
            Task { @MainActor in
                if let newValue = newValue, let categoricalResult  = model.categoricalResult(for: newValue) {
                    await chatHost.didTap(chatResult: categoricalResult)
                }
            }
        }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model
    return SearchView(chatHost: chatHost, model: model, locationProvider: locationProvider)
}
