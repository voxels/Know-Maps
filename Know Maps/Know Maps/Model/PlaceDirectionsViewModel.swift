//
//  PlaceDirectionsViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/23/23.
//

import SwiftUI
import MapKit

@MainActor
public class PlaceDirectionsViewModel : ObservableObject {
    @Published public var route:MKRoute?
    @Published public var source:MKMapItem?
    @Published public var destination:MKMapItem?
    @Published public var polyline:MKPolyline?
    @Published public var transportType:MKDirectionsTransportType = .walking
    @Published public var rawTransportType:Int = 0
    @Published public var chatRouteResults:[ChatRouteResult]?

    public init(route: MKRoute? = nil, source: MKMapItem? = nil, destination: MKMapItem? = nil, polyline: MKPolyline? = nil, transportType: MKDirectionsTransportType = .walking, rawTransportType: Int = 0, chatRouteResults: [ChatRouteResult]? = nil) {
        self.route = route
        self.source = source
        self.destination = destination
        self.polyline = polyline
        self.transportType = transportType
        self.chatRouteResults = chatRouteResults
    }
    
    public func appleMapsLaunchOptions()->[String:Any] {
        var retval = [String:Any]()
        var directionsModeValue = MKLaunchOptionsDirectionsModeDefault
        
        switch transportType {
        case.walking:
            directionsModeValue = MKLaunchOptionsDirectionsModeWalking
        case .transit:
            directionsModeValue = MKLaunchOptionsDirectionsModeTransit
        case .automobile:
            directionsModeValue = MKLaunchOptionsDirectionsModeDriving
        default:
            directionsModeValue = MKLaunchOptionsDirectionsModeDefault
        }
        
        retval[MKLaunchOptionsDirectionsModeKey] = directionsModeValue
        
        return retval
    }
}
