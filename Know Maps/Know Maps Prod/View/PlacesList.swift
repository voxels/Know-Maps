//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation

struct PlacesList: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var selectedItem: String?
    
    @Binding public var resultId:ChatResult.ID?
    @State private var showingPopover:Bool = false
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    var body: some View {
        GeometryReader { geo in
            if let _ = chatModel.selectedPlaceChatResult {
                PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $resultId)
            } else {
                
                VStack{
                    let mapHeight = chatModel.recommendedPlaceResults.count == 0 && chatModel.placeResults.count == 0 ? geo.size.height : geo.size.height / 3
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem)
                        .frame(height:mapHeight)
                    
                    if chatModel.cloudCache.hasPrivateCloudAccess {
                        if chatModel.recommendedPlaceResults.count > 0 {
                            
                            let threeColumn = [GridItem(), GridItem()]
                            ScrollView {
                                LazyVGrid(columns: threeColumn, spacing: 16) {
                                    ForEach(chatModel.filteredRecommendedPlaceResults){ result in
                                        ZStack(alignment: .bottom, content: {
                                            if let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                    case .success(let image):
                                                        image.resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(maxWidth:geo.size.width/2 - 64)
                                                    case .failure:
                                                        Image(systemName: "photo")
                                                    @unknown default:
                                                        // Since the AsyncImagePhase enum isn't frozen,
                                                        // we need to add this currently unused fallback
                                                        // to handle any new cases that might be added
                                                        // in the future:
                                                        EmptyView()
                                                    }
                                                }
                                                Rectangle().foregroundStyle(.regularMaterial).frame( height:100)
                                                VStack {
                                                    
                                                    if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                                        Spacer()
                                                        Text(result.title).bold().lineLimit(2).padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
                                                        )
                                                        Text(neighborhood).italic()
                                                    } else{
                                                        Spacer()
                                                        Text(result.title).bold().lineLimit(2).padding(8
                                                        )
                                                        Text("")
                                                    }
                                                    HStack {
                                                        if let placeResponse = result.recommendedPlaceResponse {
                                                            Text(!placeResponse.address.isEmpty ?
                                                                 placeResponse.address : placeResponse.formattedAddress )
                                                            .lineLimit(2)
                                                            .italic()
                                                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                                        }
                                                    }
                                                }.padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                                                
                                            } else {
                                                RoundedRectangle(cornerSize: CGSize(width: 16, height: 16)).foregroundStyle(.regularMaterial)
                                                VStack {
                                                    Spacer()
                                                    Text(result.title).bold().lineLimit(2).padding(8)
                                                    if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                                        
                                                        Text(neighborhood).italic()
                                                    } else{
                                                        Text("")
                                                    }
                                                    HStack {
                                                        if let placeResponse = result.recommendedPlaceResponse {
                                                            Text(!placeResponse.address.isEmpty ?
                                                                 placeResponse.address : placeResponse.formattedAddress )
                                                            .lineLimit(2)
                                                            .italic()
                                                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                                        }
                                                    }
                                                }.padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                                            }
                                            
                                        })
                                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .cornerRadius(16)
                                        .onTapGesture {
                                            chatModel.selectedPlaceChatResult = result.id
                                        }
                                    }
                                }
                            }.padding(.horizontal, 16)
                        } else if chatModel.placeResults.count > 0 {
                            let threeColumn = [GridItem(), GridItem()]
                            ScrollView {
                                LazyVGrid(columns: threeColumn, spacing: 16) {
                                    ForEach(chatModel.filteredPlaceResults){ result in
                                        ZStack(alignment: .bottom, content: {
                                            if let response = result.placeDetailsResponse, let photoResponses = response.photoResponses, let photo = photoResponses.first, let url = photo.photoUrl() {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                    case .success(let image):
                                                        image.resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(maxWidth:geo.size.width/2 - 64)
                                                    case .failure:
                                                        Image(systemName: "photo")
                                                    @unknown default:
                                                        // Since the AsyncImagePhase enum isn't frozen,
                                                        // we need to add this currently unused fallback
                                                        // to handle any new cases that might be added
                                                        // in the future:
                                                        EmptyView()
                                                    }
                                                }
                                                Rectangle().foregroundStyle(.regularMaterial).frame( height:100)
                                                VStack {
                                                    
                                                    if let neighborhood = result.placeResponse?.locality, !neighborhood.isEmpty {
                                                        Spacer()
                                                        Text(result.title).bold().lineLimit(2).padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
                                                        )
                                                        Text(neighborhood).italic()
                                                    } else{
                                                        Spacer()
                                                        Text(result.title).bold().lineLimit(2).padding(8
                                                        )
                                                        Text("")
                                                    }
                                                    HStack {
                                                        if let placeResponse = result.placeResponse {
                                                            Text(!placeResponse.address.isEmpty ?
                                                                 placeResponse.address : placeResponse.formattedAddress )
                                                            .lineLimit(2)
                                                            .italic()
                                                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                                        }
                                                    }
                                                }.padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                                                
                                            } else {
                                                RoundedRectangle(cornerSize: CGSize(width: 16, height: 16)).foregroundStyle(.regularMaterial)
                                                VStack {
                                                    Spacer()
                                                    Text(result.title).bold().lineLimit(2).padding(8)
                                                    if let neighborhood = result.placeResponse?.locality, !neighborhood.isEmpty {
                                                        
                                                        Text(neighborhood).italic()
                                                    } else{
                                                        Text("")
                                                    }
                                                    HStack {
                                                        if let placeResponse = result.placeResponse {
                                                            Text(!placeResponse.address.isEmpty ?
                                                                 placeResponse.address : placeResponse.formattedAddress )
                                                            .lineLimit(2)
                                                            .italic()
                                                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                                        }
                                                    }
                                                }.padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                                            }
                                            
                                        })
                                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .cornerRadius(16)
                                        .onTapGesture {
                                            chatModel.selectedPlaceChatResult = result.id
                                        }
                                    }
                                }
                            }.padding(.horizontal, 16)
                        } else {
                            List(chatModel.filteredPlaceResults,selection: $resultId){ result in
                                VStack {
                                    HStack {
                                        Text(result.title)
                                        Spacer()
                                    }
                                    HStack {
                                        if let placeResponse = result.placeResponse {
                                            Text(placeResponse.formattedAddress).italic()
                                        }
                                    }
                                }
                            }
                            .listStyle(.sidebar)
                        }
                    }
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
    
    return PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
