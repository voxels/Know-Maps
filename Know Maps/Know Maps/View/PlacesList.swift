//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation

struct PlacesList: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider

    @Binding public var resultId:ChatResult.ID?
    @State private var showingPopover:Bool = false
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }

    var body: some View {
        Section("Places") {
            List(chatModel.filteredPlaceResults,selection: $resultId){ result in
                HStack {
                    Text(result.title)
                    Spacer()
                    if let placeResponse = result.placeResponse {
                        Text(placeResponse.locality).italic()
                    }
                }
            }
        }.padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
    }
    
    func distanceString(for placeResponse:PlaceSearchResponse?)->String {
        var retval = ""
        guard let placeResponse = placeResponse, let queryLocationID = chatModel.selectedSourceLocationChatResult, let queryLocation = chatModel.locationChatResult(for: queryLocationID), let queryLocation = queryLocation.location else {
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
