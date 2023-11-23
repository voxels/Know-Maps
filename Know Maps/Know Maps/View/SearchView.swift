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
    @Binding public var categoricalResultId:ChatResult.ID?

    var body: some View {
        List(model.filteredResults, selection:$categoricalResultId) { result in
            ForEach(model.filteredResults) { result in
                Section {
                    
                    ForEach(result.categoricalChatResults) { chatResult in
                        Label(chatResult.title, systemImage:"folder").listItemTint(.white)
                    }
                } header: {
                    Text(result.parentCategory)
                }
            }
        }
        .searchable(text: $model.searchText)
            .onChange(of: model.searchText) { oldValue, newValue in
                if newValue == "" {
                    model.resetPlaceModel()
                    categoricalResultId = nil
                } else if newValue != oldValue, newValue != chatHost.queryIntentParameters.queryIntents.last?.caption {
                    Task {
                        try await model.didSearch(caption:model.searchText)
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
    return SearchView(chatHost: chatHost, model: model, locationProvider: locationProvider, categoricalResultId: .constant(nil))
}
