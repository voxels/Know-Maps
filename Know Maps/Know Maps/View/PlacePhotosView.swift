//
//  PlacePhotosView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlacePhotosView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @State private var position: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let photoResponses = placeDetailsResponse.photoResponses {
                    Rectangle().foregroundStyle(.thickMaterial)
                    VStack(alignment: .leading) {
                        if photoResponses.count > 0 {
                            ScrollView(.horizontal) {
                                Grid(alignment: .center) {
                                    GridRow(alignment: .center) {
                                        ForEach(photoResponses) { response in
                                            if let url = response.photoUrl() {
                                                AsyncImage(url: url) { image in
                                                    image.resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(maxWidth: geo.size.width - 16, maxHeight:geo.size.height - 32)
                                                } placeholder: {
                                                    Rectangle()
                                                        .foregroundColor(.gray)
                                                        .frame(width: geo.size.height / 2, height:geo.size.height / 2)
                                                }.padding(EdgeInsets(top: 16, leading: 8, bottom: 16, trailing: 8))
                                            }
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No photos found for this location", systemImage: "x.circle.fill")
                }
            }
        }
    }
}

#Preview {

    let locationProvider = LocationProvider()

    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel

    return PlacePhotosView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))

}
