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
            VStack{
#if os(iOS)
                if sizeClass == .compact, UIDevice.current.userInterfaceIdiom == .phone {
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem).frame(width: geo.size.width, height: geo.size.width / 3)
                }
#endif
                if chatModel.featureFlags.owns(flag: .hasPremiumSubscription) {
                    
                    if chatModel.recommendedPlaceResults.count > 0 {
                        
                        Section(content: {
                            List(chatModel.filteredRecommendedPlaceResults,selection: $resultId){ result in
                                ZStack(alignment: .bottom, content: {
                                    if let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                        AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .empty:
                                                            ProgressView()
                                                        case .success(let image):
                                                            image.resizable()
                                                                 .aspectRatio(contentMode: .fill)
                                                                 .frame(width: geo.size.width-48, height: geo.size.width-48)
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

                                    } else {
                                        VStack{
                                            Spacer()
                                            Image(systemName: "photo")
                                            Spacer()
                                        }
                                    }
                                    Rectangle().frame(width: geo.size.width-48, height: (geo.size.width) / 4).foregroundStyle(.thinMaterial)
                                    VStack {
                                        Spacer()
                                        Text(result.title)
                                        if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                            
                                            Text(neighborhood).italic()
                                        }
                                        HStack {
                                            if let placeResponse = result.recommendedPlaceResponse {
                                                Text(!placeResponse.address.isEmpty ?
                                                     placeResponse.address : placeResponse.formattedAddress )
                                                .lineLimit(1)
                                                .italic()
                                                    .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                                Spacer()
                                                Text(distanceString(latitude: placeResponse.latitude, longitude: placeResponse.longitude)).padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8))
                                            }
                                        }
                                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                                })
                                .frame(width: geo.size.width-48, height: geo.size.width - 48)
                                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 16, height: 16)))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.gray, lineWidth: 1)
                                )
                            }
                            .listStyle(.automatic)
                        }, header: {
                            Text("Recommended Places")
                        }, footer: {
                            let totalResultsFound = chatModel.filteredRecommendedPlaceResults.count
                            Text("\(totalResultsFound) places found")
                        })
                    }
                    
                    if chatModel.relatedPlaceResults.count > 0 {
                        
                        Section(content: {
                            List(chatModel.filteredPlaceResults,selection: $resultId){ result in
                                VStack {
                                    HStack {
                                        Text(result.title)
                                        Spacer()
                                    }
                                    HStack {
                                        if let placeResponse = result.placeResponse {
                                            
                                            Text(placeResponse.formattedAddress).italic()
                                            Spacer()
                                            Text(distanceString(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                                        }
                                    }
                                }
                            }
                            .listStyle(.sidebar)
                        }, header: {
                            Text("Related Places").padding(8)
                        }, footer: {
                            
                        })
                    }
                    
                } else {
                    Section(content: {
                        List(chatModel.filteredPlaceResults,selection: $resultId){ result in
                            VStack {
                                HStack {
                                    Text(result.title)
                                    Spacer()
                                }
                                HStack {
                                    if let placeResponse = result.placeResponse {
                                        Text(placeResponse.formattedAddress).italic()
                                        Spacer()
                                        Text(distanceString(latitude: placeResponse.latitude, longitude: placeResponse.longitude))
                                    }
                                }
                            }
                        }
                        .listStyle(.sidebar)
                    }, header: {
                        if chatModel.featureFlags.owns(flag: .hasPremiumSubscription){
                            Text("Matching Places").padding(8)
                        }
                    }, footer: {
                        let totalResultsFound = chatModel.filteredPlaceResults.count
                        Text("\(totalResultsFound) places found").padding(8)
                    })
                }
            }
        }
        
    }
    
    func distanceString(latitude:Double, longitude:Double)->String {
        var retval = ""

        
        var queryLocation = locationProvider.currentLocation()
        
        if let queryLocationID = chatModel.selectedSourceLocationChatResult, let queryLocationChatResult = chatModel.locationChatResult(for: queryLocationID) {
            queryLocation = queryLocationChatResult.location
        }
        
        if queryLocation == nil, !chatModel.filteredLocationResults.isEmpty, let firstResult = chatModel.filteredLocationResults.first {
            queryLocation = firstResult.location
        }
        
        guard let queryLocation = queryLocation else {
            return retval
        }
        
        let placeResponseLocation = CLLocation(latitude: latitude, longitude: longitude)
        
        let distance = queryLocation.distance(from: placeResponseLocation)
        
        let meters = Measurement(value:distance.rounded(), unit:UnitLength(forLocale: Locale.current) )
        switch Locale.current.measurementSystem {
        case .metric:
            retval = "\(meters.converted(to: .kilometers).value.formatted(.number.precision(.fractionLength(1)))) kilometers"
        case .uk, .us:
            retval = "\(meters.converted(to: .miles).value.formatted(.number.precision(.fractionLength(1)))) miles"
        default:
            retval = "\(meters.converted(to: .kilometers).value.formatted(.number.precision(.fractionLength(1)))) kilometers"
        }
        
        return retval
    }
}

#Preview {
    
    let locationProvider = LocationProvider()
    
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags(cloudCache: cloudCache)
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
