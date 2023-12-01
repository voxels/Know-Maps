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
    @State private var isPresentingShareSheet:Bool = false

    
    var body: some View {
        if isPresentingShareSheet, let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let description = placeDetailsResponse.description, !description.isEmpty  {
            let items:[Any] = [description]
            ActivityViewController(activityItems:items, applicationActivities:[UIActivity](), isPresentingShareSheet: $isPresentingShareSheet)

        } else {
            if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse{
                ScrollView() {
                    VStack() {
                        if let tips = placeDetailsResponse.tipsResponses, tips.count > 0 , let description = placeDetailsResponse.description, description.isEmpty  {
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
                            let titles = tips.compactMap { response in
                                return response.text
                            }
                            ForEach(titles, id:\.self) { response in
                                ZStack() {
                                    Rectangle().foregroundStyle(.thickMaterial)
                                    Text(response).padding()
                                }.padding()
                            }
                        } else if let tastes = placeDetailsResponse.tastes, tastes.count > 0, let description = placeDetailsResponse.description, description.isEmpty {
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
                        } else if let description = placeDetailsResponse.description, !description.isEmpty {
                            HStack() {
                                ZStack() {
                                    Rectangle().foregroundStyle(.thickMaterial)
                                    Text(description).padding()
                                }.padding()
                                Spacer()
                                ZStack {
                                    Capsule().foregroundColor(Color(uiColor:.systemFill))
                                        .frame(minWidth:60, maxWidth:60, minHeight:60, maxHeight:60)
                                    Image(systemName: "square.and.arrow.up")
                                }.padding()
                                .onTapGesture {
                                    self.isPresentingShareSheet.toggle()
                                }
                            }
                            
                            if let tips = placeDetailsResponse.tipsResponses, tips.count > 0 {
                                
                                let titles = tips.compactMap { response in
                                    return response.text
                                }
                                ForEach(titles, id:\.self) { response in
                                    ZStack() {
                                        Rectangle().foregroundStyle(.thickMaterial)
                                        Text(response).padding()
                                    }.padding()
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("No tips found for this location", systemImage: "x.circle.fill")
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
    
    return PlaceTipsView(chatHost: chatHost, chatModel: model, locationProvider: locationProvider, resultId: .constant(nil))
    
}
