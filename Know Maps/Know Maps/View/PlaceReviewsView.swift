//
//  PlaceReviewsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlaceReviewsView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?

    var body: some View {
        if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let tipsResponses = placeChatResult.placeDetailsResponse?.tipsResponses, tipsResponses.count > 0 {
            List{
                ForEach(tipsResponses, id:\.self){ response in
                    Text(response.text)
                }
            }
            
        } else {
            ContentUnavailableView("No tips found for this location", systemImage: "x.circle.fill")
        }
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let locationProvider = LocationProvider()
    let model = ChatResultViewModel(locationProvider: locationProvider)
    model.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = model

    return PlaceReviewsView(chatHost: chatHost, chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))

}
