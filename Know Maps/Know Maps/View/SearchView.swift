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
            Text(result.title)
        }.onChange(of: resultId) { oldValue, newValue in
            let result = model.filteredResults.first { checkResult in
                return checkResult.id == newValue
            }
            
            guard let result = result else {
                return
            }
            model.searchText = result.title
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
