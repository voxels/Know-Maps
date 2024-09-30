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
        if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let _ = placeDetailsResponse.tipsResponses {
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

