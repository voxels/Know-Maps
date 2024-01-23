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
                MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem).frame(width: geo.size.width, height: geo.size.width)
            }
            #endif
            Section() {
                List(chatModel.filteredPlaceResults,selection: $resultId){ result in
                    VStack {
                        HStack {
                            Text(result.title)
                            Spacer()
                        }
                        HStack {
                            if let placeResponse = result.placeResponse {
                                Text(placeResponse.locality).italic()
                                Spacer()
                                Text(distanceString(for:placeResponse))
                            }
                        }
                    }
                }
            } footer: {
                Text("\(chatModel.filteredPlaceResults.count) places found").padding(16)
            }
            .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        }
        }
        
    }
    
    func distanceString(for placeResponse:PlaceSearchResponse?)->String {
        var retval = ""
        guard let placeResponse = placeResponse else {
            return retval
            
        }
        
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
        
        let placeResponseLocation = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
        
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
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
