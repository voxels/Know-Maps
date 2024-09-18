//
//  PlaceDescriptionView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/23/24.
//

import SwiftUI

struct PlaceDescriptionView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    
    var body: some View {
        if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let tips = placeDetailsResponse.tipsResponses {
            if let description = placeDetailsResponse.description, !description.isEmpty {
                ZStack() {
                    Rectangle().foregroundStyle(.thickMaterial)
                        .cornerRadius(16)
                    Text(description).padding()
                }
            }
        }
    }
}

#Preview {
    
    let locationProvider = LocationProvider()
    
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return PlaceDescriptionView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
