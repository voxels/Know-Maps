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
    @State private var isUpdatingSelection = false
    @State private var lastCenterCoordinate: CLLocationCoordinate2D? = nil
    @State private var autocompleteTask: Task<Void, Never>? = nil
    @State private var isSearching: Bool = false
    @State private var selectedLocation:LocationResult?
    @State private var currentResult:LocationResult?
    @FocusState private var searchFocused: Bool
    
    @State private var displayedResults: [LocationResult] = []
    @State private var applyResultsTask: Task<Void, Never>? = nil
    
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
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            searchFocused = true
                            print("🔍 Toolbar Search pressed (macOS). text='\(searchText)'")
                            commitSearch()
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                    }
                    #else
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done", systemImage: "chevron.backward") {
                            dismiss()
                        }
                            .buttonStyle(.automatic)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            searchFocused = true
                            print("🔍 Toolbar Search pressed (iOS). text='\(searchText)'")
                            commitSearch()
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                    }
                    
                    #endif
                }
                .onAppear {
                    // Sync initial distance filter value from filters
                    if let distance = filters["distance"] as? Double {
                        distanceFilterValue = distance
                    }
                    autocompleteTask?.cancel()
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
        .task {
            let currentLocation: CLLocation = modelController.locationService.currentLocation()
            currentResult = LocationResult(locationName: "Current Location", location: currentLocation)
            // Initialize displayed results to current filtered results
            displayedResults = modelController.filteredLocationResults()
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
            .frame(
                idealWidth: .infinity,
                idealHeight: max(120, sizeClass == .compact ? geometry.size.width / 2 : geometry.size.width / 4)
            )
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
                            }
                        default:
                            break
                        }
                    }
            )
        }
    }
    
    func listView(geometry: GeometryProxy) -> some View {
        // Precompute frequently used values to reduce type-checker work
        let frameHeight: CGFloat = (sizeClass == .compact) ? geometry.size.height : geometry.size.height / 2

        return VStack(spacing: 0) {
        #if os(macOS)
            HStack(spacing: 8) {
                TextField("Point of Interest", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onSubmit { commitSearch() }
                Button {
                    searchFocused = true
                    print("🔍 Inline Search pressed (macOS). text='\(searchText)'")
                    commitSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        #endif
            List(selection: $selectedLocation) {
                if let current = currentResult {
                    Section("Current Location") {
                        CurrentLocationRow(title: current.locationName)
                            .onTapGesture {
                                selectedLocation = current
                                handleLocationSelection(current)
                            }
                    }
                }

                // Results Section
                Section("Results") {
                    ForEach(displayedResults) { result in
                        LocationResultRow(
                            result: result,
                            isSaved: cacheManager.cachedLocation(contains: result.locationName),
                            isSelected: modelController.selectedDestinationLocationChatResult.id == result.id,
                            addAction: { addLocationFromSwipe(result) },
                            removeAction: { removeLocation(result) }
                        )
                        .onTapGesture {
                            selectedLocation = result
                            handleLocationSelection(result)
                        }
                    }
                }
            }
            .onChange(of:selectedLocation) { _, newValue in
                guard let newValue else { return }
                modelController.setSelectedLocation(newValue)
            }
            .frame(idealWidth: .infinity, idealHeight: frameHeight)
        }
        .focused($searchFocused)
    #if os(macOS)
        .searchable(text: $searchText, prompt: "Point of Interest")
        .onSubmit(of: .search) {
            print("🔹 onSubmit(.search) fired. searchFocused=\(searchFocused) text='\(searchText)'")
            if searchFocused { commitSearch() }
        }
        .onSubmit {
            print("🔸 onSubmit (generic) fired. searchFocused=\(searchFocused) text='\(searchText)'")
            if searchFocused { commitSearch() }
        }
        .onAppear {
            // Ensure the search field can receive focus on macOS
            #if os(macOS)
            DispatchQueue.main.async {
                self.searchFocused = true
                print("🧭 macOS onAppear: searchFocused set to true")
            }
            #endif
        }
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            #if os(macOS)
            if !trimmed.isEmpty { searchFocused = true }
            #endif
            if trimmed.count > 1 {
                #if os(macOS)
                searchFocused = true
                #endif
                requestAutocomplete(for: trimmed)
            } else {
                // Cancel any pending autocomplete if below threshold
                autocompleteTask?.cancel()
                print("✋ Autocomplete canceled: below threshold (<3)")
            }
            // Batch apply results to reduce layout churn
            applyResultsTask?.cancel()
            applyResultsTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms idle
                displayedResults = modelController.filteredLocationResults()
            }
        }
    #else
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Point of Interest")
        .onSubmit(of: .search) {
            print("🔹 onSubmit(.search) fired. searchFocused=\(searchFocused) text='\(searchText)'")
            if searchFocused { commitSearch() }
        }
        .onSubmit {
            print("🔸 onSubmit (generic) fired. searchFocused=\(searchFocused) text='\(searchText)'")
            if searchFocused { commitSearch() }
        }
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 3 {
                requestAutocomplete(for: trimmed)
            } else {
                // Cancel any pending autocomplete if below threshold
                autocompleteTask?.cancel()
                print("✋ Autocomplete canceled: below threshold (<3)")
            }
            // Batch apply results to reduce layout churn
            applyResultsTask?.cancel()
            applyResultsTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms idle
                displayedResults = modelController.filteredLocationResults()
            }
        }
    #endif
    }
        
    /// Debounced autocomplete request that cancels any in-flight autocomplete task
    private func requestAutocomplete(for query: String) {
        print("🧠 requestAutocomplete(for: '\(query)') scheduling...")
        // Cancel previous autocomplete task
        autocompleteTask?.cancel()

        // If the query is empty, do nothing and allow UI to clear suggestions elsewhere
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            print("⛔️ autocomplete aborted: query below threshold (<3)")
            return
        }
        #if os(macOS)
        // Keep focus while we await debounce
        searchFocused = true
        #endif

        // Schedule a debounced task
        autocompleteTask = Task { @MainActor in
            // Debounce ~350ms to avoid flooding the network
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { print("⛔️ autocomplete canceled before fire"); return }
            guard !isSearching else { print("⛔️ autocomplete aborted: isSearching true"); return }
            #if os(macOS)
            // Re-assert focus just before firing to avoid losing it due to layout updates
            searchFocused = true
            #endif

            // Fire a lightweight autocomplete via model controller
            print("🚀 autocomplete firing with '\(trimmed)'")
            let intent = locationIntent(for: trimmed)
            Task(priority: .userInitiated) {
                do {
                    try await modelController.searchIntent(intent: intent)
                } catch {
                    modelController.analyticsManager.trackError(error: error, additionalInfo: ["source": "NavigationLocationView.autocomplete"]) 
                }
            }
        }
    }

    private func commitSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 commitSearch() called with query='\(query)' | focused=\(searchFocused)")
        guard !query.isEmpty else {
            print("⛔️ commitSearch aborted: empty query")
            return
        }
        requestAutocomplete(for: query)
        // Schedule a batched update to displayed results after commit
        applyResultsTask?.cancel()
        applyResultsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            displayedResults = modelController.filteredLocationResults()
        }
    }
    
    func locationIntent(for query:String)->AssistiveChatHostIntent {
        AssistiveChatHostIntent(caption: query, intent: .Location, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [], selectedDestinationLocation: selectedLocation ?? LocationResult(locationName: "Current Location", location: modelController.locationService.currentLocation()), placeDetailsResponses: nil, queryParameters: nil)
    }
    
    // Note: Camera updates only; do not trigger network fetches from here to avoid duplicate requests.
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
    
    /// Update camera distance while keeping the same center coordinate.
    /// This must not trigger any network requests; guarded by design.
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
    
    // MARK: - State Management Functions
    
    /// Sync local selection state to model controller
    private func syncSelectionToModel(_ selectedLocation:LocationResult) {
        handleLocationSelection(selectedLocation)
    }
    
    /// Handle location selection from list tap
    private func handleLocationSelection(_ locationResult: LocationResult) {
        print("🎯 handleLocationSelection called with \(locationResult.id)")
        
        // Cancel pending autocomplete when user explicitly selects a location
        autocompleteTask?.cancel()
        
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
                syncSelectionToModel(result)
            } catch {
                modelController.analyticsManager.trackError(
                    error: error,
                    additionalInfo: ["locationName": result.locationName]
                )
            }
        }
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

private struct CurrentLocationRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName:"circle")
                .foregroundColor(.blue)
        }
    }
}

private struct ResultRow: View {
    let title: String
    let isSaved: Bool
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(title)
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
    }
}

private struct LocationResultRow: View {
    let result: LocationResult
    let isSaved: Bool
    let isSelected: Bool
    let addAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        ResultRow(title: result.locationName, isSaved: isSaved, isSelected: isSelected)
            .contentShape(Rectangle())
            .swipeActions {
                if isSaved {
                    Button(action: removeAction) {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .tint(.red)
                } else {
                    Button(action: addAction) {
                        Label("Add", systemImage: "plus.circle")
                    }
                    .tint(.blue)
                }
            }
    }
}

