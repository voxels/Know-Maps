//
//  PlaceReviewsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlaceReviewsView: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?

    var body: some View {
        Text("Reviews")
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model

    return PlaceReviewsView(chatHost: chatHost, chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))

}
