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
                                    ZStack {
                                        ProgressView().progressViewStyle(.circular)
                                    }
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
#if os(visionOS) || os(iOS)
                            Spacer()
                            
                            ZStack {
                                Capsule()
                                    .frame(minWidth:60, maxWidth:60, minHeight:60, maxHeight:60)
                                    .foregroundColor(Color(uiColor:.systemFill))
                                Image(systemName: "square.and.arrow.up")
                            }.padding()
                                .onTapGesture {
                                    self.isPresentingShareSheet.toggle()
                                }
#endif
                            
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
            .popover(isPresented: $isPresentingShareSheet) {
                if let result = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = result.placeDetailsResponse  {
                    let items:[Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.address]
#if os(visionOS) || os(iOS)
                    ActivityViewController(activityItems:items, applicationActivities:[UIActivity](), isPresentingShareSheet: $isPresentingShareSheet)
#endif
                }
            }
        } else {
            ContentUnavailableView("No tips found for this location", systemImage: "x.circle.fill")
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
    
    return PlaceTipsView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
    
}
