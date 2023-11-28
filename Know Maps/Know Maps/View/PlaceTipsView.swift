//
//  PlaceReviewsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlaceTipsView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?

    var body: some View {
        if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let tipsResponses = placeChatResult.placeDetailsResponse?.tipsResponses, tipsResponses.count > 0 {
            List{
                ForEach(tipsResponses, id:\.self){ response in
                    Text(response.text)
                }
                if let description = placeDetailsResponse.description, !description.isEmpty {
                    Text(description)
                } else if let tips = placeDetailsResponse.tipsResponses, tips.count > 0  {
                    HStack() {
                        Spacer()
                        Button {
                            Task {
                                try await chatHost.placeDescription(chatResult: placeChatResult, delegate: chatModel)
                            }
                        } label: {
                            if chatModel.isFetchingPlaceDescription, placeChatResult.id == chatModel.fetchingPlaceID {
                                ProgressView().progressViewStyle(.circular)
                            } else {
                                Text("Generate description for \(placeDetailsResponse.searchResponse.name)")
                            }
                        }
                        .buttonStyle(.bordered)
                        .backgroundStyle(.primary)
                        Spacer()
                    }
                } else if let tastes = placeDetailsResponse.tastes, tastes.count > 0 {
                    HStack() {
                        Spacer()
                        Button {
                            Task {
                                try await chatHost.placeDescription(chatResult: placeChatResult, delegate: chatModel)
                            }
                        } label: {
                            Text("Generate description for \(placeDetailsResponse.searchResponse.name)")
                        }
                        .buttonStyle(.bordered)
                            .backgroundStyle(.primary)
                        Spacer()
                    }
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

    return PlaceTipsView(chatHost: chatHost, chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))

}
