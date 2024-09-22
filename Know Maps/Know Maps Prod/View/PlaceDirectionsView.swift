//
//  PlaceDirectionsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import CoreLocation
import MapKit
import Segment

struct PlaceDirectionsView: View {
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @ObservedObject public var model:PlaceDirectionsViewModel
    @Binding public var resultId:ChatResult.ID?
    
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var lookAroundSceneRequest:MKLookAroundSceneRequest?
    @State private var showLookAroundScene:Bool = false
    
    static let mapFrameConstraint:Double = 200000
    static let mapFrameMinimumPadding:Double = 1000
    static let polylineStrokeWidth:CGFloat = 8
    
    private var travelTime: String? {
        guard let route = model.route else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: route.expectedTravelTime)
    }
    
    var body: some View {
        if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let placeResponse = result.placeResponse {
            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
            let title = placeResponse.name
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading) {
                        ZStack(){
                            if showLookAroundScene, let lookAroundScene = lookAroundScene {
                                LookAroundPreview(initialScene: lookAroundScene)
                                    .overlay {
                                        if let source = model.source, let destination = model.destination {
                                            let launchOptions = model.appleMapsLaunchOptions()
                                            VStack(alignment: .center) {
                                                HStack {
                                                    Button("Directions", systemImage: "map.fill") {
                                                        showLookAroundScene.toggle()
                                                    }
                                                    .padding(.horizontal, 24)
                                                    .padding(.vertical, 64)
                                                    .foregroundStyle(.primary)
                                                    .backgroundStyle(.thickMaterial)
                                                    Spacer()
                                                }
                                                Spacer()
                                                Button("Open Apple Maps", systemImage: "apple.logo") {
                                                    MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                                                }
                                                .padding(8)
                                                .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    .onChange(of: model.destination) {
                                        if let destination = model.destination {
                                            Task {
                                                try await getLookAroundScene(mapItem:destination)
                                            }
                                        }
                                    }
                                    .frame(minWidth: geo.size.width, minHeight:geo.size.height * 2.0 / 3.0)
                            } else {
                                Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 1500, maximumDistance:250000)) {
                                    Marker(title, coordinate: placeCoordinate.coordinate)
                                    
                                    if let polyline = model.polyline {
                                        MapPolyline(polyline)
                                            .stroke(.blue, lineWidth: PlaceDirectionsView.polylineStrokeWidth)
                                    }
                                }
                                .mapControls {
                                    MapPitchToggle()
                                    MapUserLocationButton()
                                    MapCompass()
                                }
                                .mapStyle(.standard)
                                .frame(minWidth: geo.size.width-48, minHeight:geo.size.height * 2.0 / 3.0)
                                .cornerRadius(16)
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                                .overlay {
                                    if let source = model.source, let destination = model.destination {
                                        let launchOptions = model.appleMapsLaunchOptions()
                                        VStack(alignment: .center) {
                                            if lookAroundScene != nil {
                                                HStack {
                                                    Button("Look Around", systemImage: "binoculars.fill") {
                                                        showLookAroundScene.toggle()
                                                    }
                                                    .padding(36)
                                                    .foregroundStyle(.primary)
                                                    Spacer()
                                                }
                                            }
                                            Spacer()
                                            Button("Open Apple Maps", systemImage: "apple.logo") {
                                                MKMapItem.openMaps(with: [source,destination], launchOptions: launchOptions)
                                            }
                                            .padding(8)
                                            .foregroundStyle(.primary)
                                        }
                                    }
                                    
                                }
                                .onAppear {
                                    if let destination = model.destination {
                                        Task {
                                            try await getLookAroundScene(mapItem:destination)
                                        }
                                    }
                                }
                            }
                        }
                        VStack {
                            if !showLookAroundScene {
                                Picker("Transport Type", selection: $model.rawTransportType) {
                                    Text(PlaceDirectionsViewModel.RawTransportType.Automobile.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Automobile)
                                    Text(PlaceDirectionsViewModel.RawTransportType.Walking.rawValue).tag(PlaceDirectionsViewModel.RawTransportType.Walking)
                                }.foregroundStyle(.primary)
                                    .pickerStyle(.palette)
                                Picker("Route Start Location", selection:$model.rawLocationIdent) {
                                    ForEach(chatModel.filteredLocationResults, id:\.self) { result in
                                        Text(result.locationName).tag(result.id.uuidString)
                                    }
                                }.foregroundStyle(.primary)
                                    .pickerStyle(.menu)
                            }
                        }.padding(.horizontal, 16)
                        if let chatRouteResults = model.chatRouteResults, chatRouteResults.count > 0  {
                            VStack(alignment: .leading) {
                                ForEach(chatRouteResults) { chatRouteResult in
                                    Text(chatRouteResult.instructions)
                                }
                            }.padding(16)
                        }
                    }
                }
            }
            .onChange(of: resultId) { oldValue, newValue in
                guard let placeChatResult = chatModel.placeChatResult(for: newValue), let placeResponse = placeChatResult.placeResponse else {
                    return
                }
                
                if oldValue != newValue, let currentLocationID = chatModel.selectedSourceLocationChatResult, let locationResult = chatModel.locationChatResult(for: currentLocationID), let currentLocation = locationResult.location, let sourceMapItem = mapItem(for: currentLocation, name:locationResult.locationName), let destinationMapItem = mapItem(for: CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude), name:placeResponse.name) {
                    Task {
                        do {
                            try await getDirections(source:sourceMapItem, destination:destinationMapItem, model:model)
                            self.resultId = resultId
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                        
                    }
                }
            }
            .onChange(of: chatModel.selectedSourceLocationChatResult, { oldValue, newValue in
                if let newValue = newValue {
                    model.rawLocationIdent = newValue.uuidString
                }
            })
            .onChange(of: model.rawLocationIdent, { oldValue, newValue in
                guard newValue != oldValue else {
                    return
                }
                
                if let ident = UUID(uuidString: newValue) {
                    guard let placeChatResult = chatModel.placeChatResult(for: resultId), let placeResponse = placeChatResult.placeResponse else {
                        return
                    }
                    
                    chatModel.selectedSourceLocationChatResult = ident
                    let _ = Task{
                        do {
                            try await refreshDirections(with: placeResponse)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            })
            .onChange(of: model.rawTransportType) { oldValue, newValue in
                switch newValue {
                case .Walking:
                    model.transportType = .walking
                case .Transit:
                    model.transportType = .transit
                case .Automobile:
                    model.transportType = .automobile
                }
            }
            .onChange(of: model.transportType) { oldValue, newValue in
                guard let placeChatResult = chatModel.placeChatResult(for: resultId), let placeResponse = placeChatResult.placeResponse else {
                    return
                }
                
                if newValue == oldValue {
                    return
                }
                
                let _ = Task{
                    do {
                        try await refreshDirections(with: placeResponse)
                    } catch {
                        chatModel.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .onChange(of: model.source) { oldValue, newValue in
                guard let placeChatResult = chatModel.placeChatResult(for: resultId), let placeResponse = placeChatResult.placeResponse else {
                    return
                }
                
                if newValue == oldValue {
                    return
                }
                
                
                let _ = Task{
                    do {
                        try await refreshDirections(with: placeResponse)
                    } catch {
                        chatModel.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .onChange(of: model.destination) { oldValue, newValue in
                if let newValue = newValue {
                    Task {
                        do {
                            try await getLookAroundScene(mapItem:newValue)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
                
                let _ = Task{
                    do {
                        try await refreshDirections(with: placeResponse)
                    } catch {
                        chatModel.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            }
            .task {
                model.rawLocationIdent = chatModel.selectedDestinationLocationChatResult?.uuidString ?? chatModel.currentLocationResult.id.uuidString
                
                if let destination = model.destination  {
                    do {
                        try await getLookAroundScene(mapItem:destination)
                        if chatModel.selectedSourceLocationChatResult == nil {
                            chatModel.selectedSourceLocationChatResult = chatHost.lastLocationIntent()?.selectedDestinationLocationID
                            if let selectedSourceLocationChatResult = chatModel.selectedSourceLocationChatResult {
                                model.rawLocationIdent = selectedSourceLocationChatResult.uuidString
                            }
                        }
                        try await refreshDirections(with: placeResponse)
                    } catch {
                        chatModel.analytics?.track(name: "error \(error)")
                        print(error)
                    }
                } else {
                    if chatModel.selectedSourceLocationChatResult == nil {
                        chatModel.selectedSourceLocationChatResult = chatHost.lastLocationIntent()?.selectedDestinationLocationID
                        if let selectedSourceLocationChatResult = chatModel.selectedSourceLocationChatResult {
                            model.rawLocationIdent = selectedSourceLocationChatResult.uuidString
                        }
                    }
                    let _ = Task{
                        do {
                            try await refreshDirections(with: placeResponse)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
                
                
            }
        }
        else {
            ContentUnavailableView("No route available", systemImage: "x.circle.fill")
        }
    }
    
    func refreshDirections(with placeResponse:PlaceSearchResponse) async throws {
        if let currentLocationID = chatModel.selectedSourceLocationChatResult, let locationResult = chatModel.locationChatResult(for: currentLocationID), let currentLocation = locationResult.location, let sourceMapItem = mapItem(for: currentLocation, name:locationResult.locationName), let destinationMapItem = mapItem(for: CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude), name:placeResponse.name) {
            Task {
                do {
                    try await getDirections(source:sourceMapItem, destination:destinationMapItem, model:model)
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                }
                
            }
        }
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
    func getDirections(source:MKMapItem?, destination:MKMapItem?, model:PlaceDirectionsViewModel) async throws {
        
        guard let source = source, let destination = destination else {
            return
        }
        
        model.route = nil
        model.polyline = nil
        model.chatRouteResults?.removeAll()
        
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = model.transportType
        
        let directions = MKDirections(request: request)
        
        let response = try await directions.calculate()
        model.source = source
        model.destination = destination
        model.route = response.routes.first
        if let route = model.route {
            model.polyline = route.polyline
            model.chatRouteResults = route.steps.compactMap({ step in
                let instructions = step.instructions
                if !instructions.isEmpty {
                    return ChatRouteResult(route: route, instructions: instructions)
                } else {
                    return route.steps.count > 0 ? nil : ChatRouteResult(route: route, instructions: "Check Apple Maps for a route")
                }
            })
            
            if let routeResults = model.chatRouteResults, routeResults.isEmpty {
                model.chatRouteResults = [ChatRouteResult(route: route, instructions: "Check Apple Maps for a route")]
            }
        } else {
            model.chatRouteResults = [ChatRouteResult(route: nil, instructions: "Check Apple Maps for a route")]
        }
    }
    
    @MainActor
    func getLookAroundScene (mapItem:MKMapItem) async throws {
        if let request = lookAroundSceneRequest, request.isLoading {
            return
        }
        
        lookAroundSceneRequest = MKLookAroundSceneRequest(coordinate: mapItem.placemark.coordinate)
        
        let scene = try await lookAroundSceneRequest?.scene
        lookAroundScene = scene
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
    let model = PlaceDirectionsViewModel(rawLocationIdent: "")
    
    return PlaceDirectionsView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, model: model, resultId: .constant(nil))
}
