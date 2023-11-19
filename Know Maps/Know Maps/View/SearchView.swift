//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var model:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?

    var body: some View {
        List(model.filteredResults,selection: $resultId){ result in
            Text(result.title).bold()
        }.searchable(text: $model.searchText)
            .onChange(of: model.searchText) { oldValue, newValue in
                if newValue == "" {
                    model.selectedPlaceResult = nil
                    model.resetPlaceModel()
                    resultId = nil
                } else {
                    Task {
                        await model.didSearch(caption: model.searchText)
                    }
                }
            }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model
    return SearchView(chatHost: chatHost, model: model, locationProvider: locationProvider, resultId: .constant(nil))
}
