//
//  PlacePhotosView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlacePhotosView: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @State private var position: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse {
                    Rectangle().foregroundStyle(.thickMaterial)
                    VStack(alignment: .leading) {
                        if let photoResponses = placeDetailsResponse.photoResponses {
                            ScrollView(.horizontal) {
                                LazyHStack {
                                    ForEach(photoResponses) { response in
                                        if let url = response.photoUrl() {
                                            AsyncImage(url: url) { image in
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(maxWidth: geo.size.height)
                                            } placeholder: {
                                                Rectangle()
                                                    .foregroundColor(.gray)
                                                    .frame(width: geo.size.width, height:geo.size.height)
                                            }
                                            
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }
                    }
                } else {
                    Text("No details found")
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

    return PlacePhotosView(chatHost: chatHost, chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))

}
