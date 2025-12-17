//
//  PlaceDirectionsViewModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/23/23.
//

import SwiftUI
import MapKit
import Combine


public class PlaceDirectionsViewModel : ObservableObject {
    @Published var lookAroundScene: Any?
    @Published var showLookAroundScene:Bool = false
    @Published public var route:MKRoute?
    public var source:MKMapItem?
    public var destination:MKMapItem?
    @Published public var polyline:MKPolyline?
    @Published public var transportType:MKDirectionsTransportType = .automobile
    @Published public var rawTransportType:RawTransportType = .Automobile
    // @Published public var rawLocationIdent:String! // Not used
    @Published public var chatRouteResults:[ChatRouteResult]?

    private var lookAroundSceneRequest:MKLookAroundSceneRequest?
    private var isFetchingDirections:Bool = false

    public enum RawTransportType : String {
        case Walking
        case Transit
        case Automobile
    }
    
    public init(route: MKRoute? = nil, source: MKMapItem? = nil, destination: MKMapItem? = nil, polyline: MKPolyline? = nil, transportType: MKDirectionsTransportType = .automobile, rawTransportType: RawTransportType = .Automobile, chatRouteResults: [ChatRouteResult]? = nil, rawLocationIdent:String) {
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
        case .walking:
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
    

    @MainActor
    func refreshDirections(with source:CLLocation, destination:CLLocation) async throws {
        if isFetchingDirections{
            return
        }
        
        isFetchingDirections = true
        
        if let sourceMapItem = mapItem(for: source), let destinationMapItem = mapItem(for:destination) {
            try await getDirections(source:sourceMapItem, destination:destinationMapItem)
            Task { [ weak self ] in
                guard let self else { return }
                try await self.getLookAroundScene(mapItem:destinationMapItem)
            }
        }
        
        isFetchingDirections = false
    }
    

    func mapItem(for location:CLLocation?, name:String? = nil)->MKMapItem? {
        guard let location = location, let placemark = placemark(for: location) else {
            return nil
        }
        
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        
        return mapItem
    }
    
    func placemark(for location:CLLocation?)->MKPlacemark? {
        guard let location = location else {
            return nil
        }
        return MKPlacemark(coordinate: location.coordinate)
    }
    

    @MainActor
    func getDirections(source:MKMapItem, destination:MKMapItem) async throws {
        self.source = source
        self.destination = destination

        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        
        let response = try await directions.calculate()
            self.route = response.routes.first
        if let route = route {
                polyline = route.polyline
                chatRouteResults = route.steps.compactMap({ step in
                    let instructions = step.instructions
                    if !instructions.isEmpty {
                        return ChatRouteResult(route: route, instructions: instructions)
                    } else {
                        return route.steps.count > 0 ? nil : ChatRouteResult(route: route, instructions: "Check Apple Maps for a route")
                    }
                })
            
            if let routeResults = chatRouteResults, routeResults.isEmpty {
                    chatRouteResults = [ChatRouteResult(route: route, instructions: "Check Apple Maps for a route")]
            }
        } else {
                chatRouteResults = [ChatRouteResult(route: nil, instructions: "Check Apple Maps for a route")]
        }
    }
    
    func getLookAroundScene (mapItem:MKMapItem) async throws {
        if let request = lookAroundSceneRequest, request.isLoading {
            return
        }
        
        let request = MKLookAroundSceneRequest(coordinate: mapItem.placemark.coordinate)
            lookAroundSceneRequest = request
        
        guard let scene = try await self.lookAroundSceneRequest?.scene else  { return }
        await self.setLookAroundScene(scene)
   }
    
    @MainActor
    func setLookAroundScene(_ newValue:Any) {
        lookAroundScene = newValue
    }
}
