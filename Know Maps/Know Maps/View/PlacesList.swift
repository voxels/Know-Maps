//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct PlacesList: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var model:ChatResultViewModel
    @Binding public var resultId:ChatResult.ID?
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }

    var body: some View {
        List(model.filteredPlaceResults,selection: $resultId){ result in
            if let placeResponse =
                result.placeDetailsResponse {
                VStack{
                    HStack{
                        Text(result.title).foregroundColor(Color(uiColor: UIColor.label)).bold()
                        Spacer()
                        if let price = placeResponse.price {
                            ZStack {
                                Capsule().frame(width: 44, height: 44, alignment: .center).foregroundColor(Color.accentColor)
                                switch price {
                                case 1:
                                    Text("$")
                                case 2:
                                    Text("$$")
                                case 3:
                                    Text("$$$")
                                case 4:
                                    Text("$$$$")
                                default:
                                    Text("\(price)")
                                        .foregroundColor(Color(uiColor: UIColor.label))
                                }
                            }
                        }
                        
                        let rating = placeResponse.rating
                        if rating > 0 {
                            ZStack {
                                Capsule().frame(width: 44, height: 44, alignment: .center).foregroundColor(Color.accentColor)
                                Text(PlacesList.formatter.string(from: NSNumber(value: rating)) ?? "0")
                            }
                        }
                    }
                    if let description = placeResponse.description {
                        Text(description)
                            .truncationMode(.tail)
                            .frame(maxHeight:300)
                    } else if let tips = placeResponse.tipsResponses, tips.count > 0  {
                        Button {
                            Task {
                                try await chatHost.placeDescription(chatResult: result, delegate: model)
                                model.selectedPlaceChatResult = result.id
                            }
                        } label: {
                            if model.isFetchingPlaceDescription, result.id == model.fetchingPlaceID {
                                ProgressView().progressViewStyle(.circular)
                            } else {
                                Text("Generate GPT-4 Description for \(placeResponse.searchResponse.name)")
                            }
                        }.buttonStyle(.bordered)
                    } else if let tastes = placeResponse.tastes, tastes.count > 0 {
                        Button {
                            Task {
                                try await chatHost.placeDescription(chatResult: result, delegate: model)
                            }
                        } label: {
                            Text("Generate GPT-4 Description for \(placeResponse.searchResponse.name)")
                        }.buttonStyle(.bordered)
                    }
                }
            } else {
                Text(result.title).foregroundColor(Color(uiColor: UIColor.label))
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

    return PlacesList(chatHost: chatHost, model: model, resultId: .constant(nil))
}
