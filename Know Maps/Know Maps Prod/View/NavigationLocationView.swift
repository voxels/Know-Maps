//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct NavigationLocationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var filters:[String:Any]
    @State private var searchIsPresented = false
    @State private var searchText:String = ""
    @State public var cameraPosition:MapCameraPosition = .automatic
    @State public var selectedMapItem: String? = nil
    @State public var distanceFilterValue:Double = 20

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                mapView(geometry: geometry)
                FiltersView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel, filters: $searchSavedViewModel.filters, distanceFilterValue: $distanceFilterValue)
                listView(geometry: geometry)
            }
        }
    }
    
    
    func mapView(geometry:GeometryProxy) -> some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all, selection: $selectedMapItem) {
                ForEach(modelController.mapPlaceResults) { result in
                    if let placeResponse = result.placeResponse {
                        Marker(result.title, coordinate: CLLocationCoordinate2D(latitude: placeResponse.latitude, longitude: placeResponse.longitude)).tag(placeResponse.fsqID)
                    }
                }
            }
            .mapControls {
                MapPitchToggle()
                MapUserLocationButton()
                MapCompass()
            }
            .frame(idealHeight: geometry.size.width)
            .mapStyle(.standard)
            .cornerRadius(10)
            .task {
                let selectedResult = modelController.currentLocationResult
                if let location = selectedResult.location {
                    cameraPosition = MapCameraPosition.camera(MapCamera(centerCoordinate: location.coordinate, distance: distanceFilterValue * 1000))
                } else {
                    cameraPosition =  .userLocation(fallback: .automatic)
                }
            }
            .onChange(of: modelController.selectedDestinationLocationChatResult) { oldValue, newValue in
                if let newLocation = newValue {
                    updateCamera(for: newLocation)
                } else {
                    updateCamera(for: modelController.currentLocationResult.id)
                }
            }
            .onChange(of: distanceFilterValue) { oldValue, newValue in
                if let selectedDestionationLocaitonChatResult = modelController.selectedDestinationLocationChatResult {
                    updateCamera(for: selectedDestionationLocaitonChatResult)
                }
            }
            /*
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag?):
                            let point = drag.location
                            if let coordinate = proxy.convert(point, from: .local) {
                                withAnimation {
                                    cameraPosition = .camera(
                                        MapCamera(
                                            centerCoordinate: coordinate,
                                            distance: distanceFilterValue * 1000
                                        )
                                    )
                                    search(intent: .Location, query: "\(coordinate.latitude), \(coordinate.longitude)")
                                }
                            }
                        default:
                            break
                        }
                    }
            )
             */
        }
    }
    
    
    
    func listView(geometry:GeometryProxy) -> some View {
        List(modelController.filteredLocationResults(cacheManager: cacheManager), selection:$modelController.selectedDestinationLocationChatResult) { result in
            let isSaved = cacheManager.cachedLocation(contains:result.locationName)
            HStack {
                Text(result.locationName)
                Spacer()
                isSaved ? Image(systemName: "checkmark.circle.fill") : Image(systemName: "circle")
            }
            .swipeActions {
                HStack {
                    if isSaved {
                        Button(action: {
                            if let location = result.location {
                                Task(priority:.userInitiated) {
                                    await searchSavedViewModel.removeCachedResults(
                                        group: "Location",
                                        identity: cacheManager.cachedLocationIdentity(for: location),
                                        cacheManager: cacheManager,
                                        modelController: modelController
                                    )
                                }
                            }
                        }, label: {
                            Label("Remove", systemImage: "minus.circle")
                        })
                        .labelStyle(.titleAndIcon)
                    } else {
                        Button(action: {
                            if let location = result.location {
                                Task(priority:.userInitiated) {
                                    do {
                                        try await searchSavedViewModel.addLocation(
                                            parent:result,
                                            location: location,
                                            cacheManager: cacheManager,
                                            modelController: modelController
                                        )
                                        modelController.selectedDestinationLocationChatResult = modelController.filteredLocationResults(cacheManager:cacheManager).first(where: {$0.locationName == result.locationName})?.id
                                    } catch {
                                        modelController.analyticsManager.trackError(
                                            error: error,
                                            additionalInfo: nil
                                        )
                                    }
                                }
                            }
                        }, label: {
                            Label("Add", systemImage: "plus.circle")
                        })
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .frame(idealWidth: .infinity, idealHeight:geometry.size.height)
        .searchable(text: $searchText, placement:.navigationBarDrawer(displayMode: .always), prompt: "Point of Interest")
        .onChange(of: searchText) { oldValue, newValue in
                if !newValue.isEmpty, newValue != oldValue {
                    search(intent: .Location, query: newValue )
                }
            }
    }
    
    func search(intent:AssistiveChatHostService.Intent, query: String? = nil) {
        if let query, !query.isEmpty {
            Task(priority:.userInitiated) {
                await searchSavedViewModel.search(
                    caption: query,
                    selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult, intent: intent, filters: searchSavedViewModel.filters,
                    chatModel: chatModel,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
            }
        }
    }
    
    private func updateCamera(for locationResult: UUID) {
        if let locationResult = modelController.locationChatResult(for: locationResult, in: modelController.filteredLocationResults(cacheManager: cacheManager)), let location = locationResult.location {
            withAnimation {
                cameraPosition = MapCameraPosition.camera(MapCamera(centerCoordinate:location.coordinate
                                                                    , distance: distanceFilterValue * 1000))
            }
        }
    }
}
