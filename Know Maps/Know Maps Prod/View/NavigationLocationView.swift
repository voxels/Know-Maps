//
//  NavigationLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/15/23.
//

import SwiftUI
import CoreLocation
import MapKit

// Simplify type-checking for filters passed through SwiftUI bindings
public typealias FiltersDictionary = [String: Any]

struct NavigationLocationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var filters: FiltersDictionary
    @State private var searchIsPresented = false
    @State private var searchText:String = ""
    @State public var cameraPosition:MapCameraPosition = .automatic
    @State public var selectedMapItem: String? = nil
    @State public var distanceFilterValue: Double = 20
    @State private var selectedLocation: LocationResult?
    @State private var filteredLocationResults: [LocationResult] = []
    @State private var isUpdatingSelection = false
    @State private var lastCenterCoordinate: CLLocationCoordinate2D? = nil

    // MARK: - Computed Properties
    
    private func makeFiltersView() -> FiltersContainerView {
        // Break up complex binding expression to help the type-checker
        let chatModelBinding = $chatModel
        let cacheManagerBinding = $cacheManager
        let modelControllerBinding = $modelController
        let searchSavedViewModelBinding = $searchSavedViewModel
        let filtersBinding = $filters
        let distanceBinding = $distanceFilterValue

        return FiltersContainerView(
            chatModel: chatModelBinding,
            cacheManager: cacheManagerBinding,
            modelController: modelControllerBinding,
            searchSavedViewModel: searchSavedViewModelBinding,
            filters: filtersBinding,
            distanceFilterValue: distanceBinding
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    mapView(geometry: geometry)
                    makeFiltersView()
                    listView(geometry: geometry)
                }
                .frame(maxWidth: .infinity, maxHeight:.infinity, alignment: .init(horizontal: .center, vertical: .top))
                .toolbar {
                    #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done", systemImage: "chevron.backward") {
                            dismiss()
                        }
                            .buttonStyle(.automatic)
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button(action: {
                            addSelectedLocation()
                        }) {
                            Image(systemName: "plus")
                        }
                        .disabled(selectedLocationId == nil || isSelectedLocationAlreadySaved())
                        .accessibilityLabel("Add Selected Location")
                        .accessibilityHint("Adds the currently selected location to your saved locations")
                    }

                    #else
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done", systemImage: "chevron.backward") {
                            dismiss()
                        }
                            .buttonStyle(.automatic)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            if let selectedLocation {
                                addLocationFromSwipe(selectedLocation)
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                        .disabled(selectedLocation == nil || isSelectedLocationAlreadySaved())
                        .accessibilityLabel("Add Selected Location")
                        .accessibilityHint("Adds the currently selected location to your saved locations")
                    }
                    #endif
                }
                .onAppear {
                    refreshLocationResults()
                    initializeSelection()
                    updateCameraToSelectedDestination()
                    // Sync initial distance filter value from filters
                    if let distance = filters["distance"] as? Double {
                        distanceFilterValue = distance
                    }
                }
                .onChange(of: modelController.selectedDestinationLocationChatResult) { oldValue, newValue in
                    if !isUpdatingSelection {
                        selectedLocation = newValue
                        updateCamera(for: newValue)
                    }
                }
                .onChange(of: cacheManager.cachedLocationResults.count) { _, _ in
                    refreshLocationResults()
                }
                .onChange(of: (filters["distance"] as? Double)) { oldValue, newValue in
                    guard let newValue else { return }
                    let clamped = max(newValue, 0.5)
                    if clamped != distanceFilterValue {
                        distanceFilterValue = clamped
                    }
                }
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
            .onMapCameraChange(frequency: .continuous) { context in
                // Keep the last center coordinate in sync with user pan/zoom
                lastCenterCoordinate = context.region.center
            }
            .frame(idealWidth: .infinity, idealHeight:sizeClass == .compact ? geometry.size.width / 2 : geometry.size.width / 4)
            .mapStyle(.hybrid)
            .cornerRadius(32)
            .padding(16)
            .task {
                lastCenterCoordinate = modelController.selectedDestinationLocationChatResult.location.coordinate
                    cameraPosition = MapCameraPosition.camera(
                        MapCamera(
                            centerCoordinate: lastCenterCoordinate!,
                            distance: distanceFilterValue * 1000
                        )
                    )
            }
            .onChange(of: distanceFilterValue) { oldValue, newValue in
                // Update the map camera continuously while dragging; do not mutate filters here
                updateCameraDistance()
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        switch value {
                        case .second(true, .some(let drag)):
                            let point = drag.location
                            if let coordinate = proxy.convert(point, from: .local) {
                                    lastCenterCoordinate = coordinate
                                    cameraPosition = .camera(
                                        MapCamera(
                                            centerCoordinate: coordinate,
                                            distance: distanceFilterValue * 1000
                                        )
                                    )
                                    search(intent: .Location, query: "\(coordinate.latitude), \(coordinate.longitude)")
                            }
                        default:
                            break
                        }
                    }
            )
        }
    }
    
    
    
    func listView(geometry:GeometryProxy) -> some View {
        List() {
            // Section for Current Location (always shown as unsaved)
            Section("Current Location") {
                let currentLocation = modelController.locationService.currentLocation()
                let currentResult = LocationResult(locationName: "Current Location", location: currentLocation)
                let isSelected = selectedLocation == currentResult
                HStack {
                    Text(currentResult.locationName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Spacer()
                    // Always show as unsaved indicator (not a checkmark)
                    Image(systemName: isSelected ? "plus.circle" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    handleLocationSelection(currentResult)
                }
            }

            // Section for other search results
            Section("Results") {
                ForEach(filteredLocationResults, id: \.id) { result in
                    let isSaved = cacheManager.cachedLocation(contains: result.locationName)
                    let isSelected = selectedLocation == result

                    HStack {
                        Text(result.locationName)
                            .fontWeight(isSelected ? .semibold : .regular)
                        Spacer()
                        if isSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if isSelected {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleLocationSelection(result)
                    }
                    .swipeActions {
                        if isSaved {
                            Button(action: {
                                removeLocation(result)
                            }, label: {
                                Label("Remove", systemImage: "minus.circle")
                            })
                            .tint(.red)
                        } else {
                            Button(action: {
                                addLocationFromSwipe(result)
                            }, label: {
                                Label("Add", systemImage: "plus.circle")
                            })
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .frame(idealWidth: .infinity, idealHeight: sizeClass == .compact ? geometry.size.height : geometry.size.height / 2)
        #if os(macOS)
        .searchable(text: $searchText, prompt: "Point of Interest")
        #else
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Point of Interest")
        #endif
        // Only search when user submits (presses Return) instead of on every change
        .onSubmit(of: .search) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                search(intent: .Location, query: query)
            }
        }
    }
    
    func search(intent:AssistiveChatHostService.Intent, query: String? = nil) {
        guard let query, !query.isEmpty else { return }
        
        Task(priority:.userInitiated) {
            do {
                try await chatModel.didSearch(caption:query, selectedDestinationChatResult:modelController.selectedDestinationLocationChatResult, intent:intent, filters: searchSavedViewModel.filters, modelController: modelController)
            } catch {
                modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
            }
            
            if intent == .Location {
                // Refresh results and validate selection after location search
                await MainActor.run {
                    refreshLocationResults()
                    // Update selection if it changed in the model controller
                    if modelController.selectedDestinationLocationChatResult != selectedLocation {
                        selectedLocation = modelController.selectedDestinationLocationChatResult
                    }
                }
            }
        }
    }
    
    private func updateCamera(for locationResult: LocationResult) {
        print("📹 updateCamera called for \(locationResult.id)")
           print("📹 Found location: \(locationResult.locationName) at \(locationResult.location.coordinate)")
        withAnimation(.easeInOut(duration: 0.5)) {
            lastCenterCoordinate = locationResult.location.coordinate
            cameraPosition = MapCameraPosition.camera(
                MapCamera(
                    centerCoordinate: lastCenterCoordinate!,
                    distance: distanceFilterValue * 1000
                )
            )
        }
    }
    
    /// Update camera distance while keeping the same center coordinate
    private func updateCameraDistance() {
//        print("📹 updateCameraDistance called with distance: \(distanceFilterValue)")

        if let center = lastCenterCoordinate {
                cameraPosition = MapCameraPosition.camera(
                    MapCamera(
                        centerCoordinate: center,
                        distance: distanceFilterValue * 1000
                    )
                )
        }

        // If we have a selected location, update to that location with new distance
        lastCenterCoordinate = modelController.selectedDestinationLocationChatResult.location.coordinate
                cameraPosition = MapCameraPosition.camera(
                    MapCamera(
                        centerCoordinate: lastCenterCoordinate!,
                        distance: distanceFilterValue * 1000
                    )
                )
    }
    
    private func updateCameraToSelectedDestination() {
        if selectedLocation == nil {
            modelController.setSelectedLocation(nil)
        }
        syncSelectionToModel()
    }
    
    // MARK: - State Management Functions
    
    /// Refresh the cached filtered location results
    private func refreshLocationResults() {
        filteredLocationResults = modelController.filteredLocationResults()
        
        // Update local selection if model controller's selection changed
        if selectedLocation != modelController.selectedDestinationLocationChatResult {
            selectedLocation = modelController.selectedDestinationLocationChatResult
        }
    }
    
    /// Initialize selection state from model controller
    private func initializeSelection() {
        selectedLocation = modelController.selectedDestinationLocationChatResult
        syncSelectionToModel()
        
        print("🎯 initializeSelection: selectedLocationId = \(selectedLocation?.id ?? "nil")")
    }
    
    /// Sync local selection state to model controller
    private func syncSelectionToModel() {
        guard !isUpdatingSelection else { return }
        isUpdatingSelection = true
        
        Task { @MainActor in
            if let selectedLocation = selectedLocation {
                handleLocationSelection(selectedLocation)
            }
            isUpdatingSelection = false
        }
    }
    
    /// Handle location selection from list tap
    private func handleLocationSelection(_ locationResult: LocationResult) {
        print("🎯 handleLocationSelection called with \(locationResult.id)")
        
        // Don't sync back to avoid loops - the selection binding already updated selectedLocationId
        // Just update camera and model controller
        updateCamera(for: locationResult)
        
        // Sync to model controller without triggering local state updates
        isUpdatingSelection = true
        Task { @MainActor in
            print("📍 Setting model controller selection to \(locationResult.id)")
            modelController.setSelectedLocation(locationResult)
            isUpdatingSelection = false
        }
    }
    
    /// Remove a location (from swipe action)
    private func removeLocation(_ result: LocationResult) {
        let location = result.location
        Task(priority: .userInitiated) {
            await searchSavedViewModel.removeCachedResults(
                group: "Location",
                identity: cacheManager.cachedLocationIdentity(for: location),
                cacheManager: cacheManager,
                modelController: modelController
            )
            
            await MainActor.run {
                refreshLocationResults()
            }
        }
    }
    
    /// Add location from swipe action  
    private func addLocationFromSwipe(_ result: LocationResult) {
        let location = result.location
        
        Task(priority: .userInitiated) {
            do {
                try await searchSavedViewModel.addLocation(
                    parent: result,
                    location: location,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
                
                await MainActor.run {
                    refreshLocationResults()
                    selectedLocation = result
                    syncSelectionToModel()
                }
                
            } catch {
                modelController.analyticsManager.trackError(
                    error: error,
                    additionalInfo: ["locationName": result.locationName]
                )
            }
        }
    }
    
    /// Check if the currently selected location is already saved
    private func isSelectedLocationAlreadySaved() -> Bool {
        
        guard let selected = selectedLocation, let filteredLocation = filteredLocationResults.first(where: { $0.id == selected.id }) else { return false }
        return cacheManager.cachedLocation(contains: filteredLocation.locationName)
    }
}

private struct FiltersContainerView: View {
    @Binding var chatModel: ChatResultViewModel
    @Binding var cacheManager: CloudCacheManager
    @Binding var modelController: DefaultModelController
    @Binding var searchSavedViewModel: SearchSavedViewModel
    @Binding var filters: FiltersDictionary
    @Binding var distanceFilterValue: Double

    var body: some View {
        FiltersView(
            chatModel: $chatModel,
            cacheManager: $cacheManager,
            modelController: $modelController,
            searchSavedViewModel: $searchSavedViewModel,
            filters: $filters,
            distanceFilterValue: $distanceFilterValue
        )
    }
}

