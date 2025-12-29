import SwiftUI
import MapKit
import SwiftData

struct UnifiedSearchView: View {
    @Environment(\.modelContext) private var modelContext
    var modelController: DefaultModelController
    var cacheManager: CloudCacheManager
    
    @EnvironmentObject var authService: AppleAuthenticationService
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedResult: ChatResult?
    @State private var activePills: Set<String> = []
    @State private var showFavorites: Bool = false
    @State private var searchRadius: Double = 20.0
    @State private var showFilters: Bool = false
    @State private var showSettings: Bool = false
    @State private var locationQuery: String = ""
    @State private var showSearchHere: Bool = false
    @State private var lastedCameraDistance: Double? = nil
    @FocusState private var isSearchFieldFocused: Bool
    
    private let quickCategories = ["Coffee", "Pizza", "Parks", "Bars", "Museums", "Gyms"]
    
    private var filteredIndustries: [CategoryResult] {
        guard !searchText.isEmpty else { return [] }
        return modelController.industryResults.filter { 
            $0.parentCategory.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    private var filteredTastes: [CategoryResult] {
        guard !searchText.isEmpty else { return [] }
        return modelController.tasteResults.filter { 
            $0.parentCategory.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    var body: some View {
            ZStack {
                mapLayer
                VStack {
                    Spacer()
                    searchInterface
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSettings) {
                SettingsView(cacheManager: cacheManager, modelController: modelController)
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersSheet(searchRadius: $searchRadius, locationQuery: $locationQuery, modelController: modelController)
                    .presentationDetents([.medium, .fraction(0.4)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedResult) { result in
                NavigationStack {
                    PlaceDetailSheet(result: result, modelController: modelController, cacheManager: cacheManager)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView(cacheManager: cacheManager, modelController: modelController)
            }
            .onChange(of: searchRadius) { oldValue, newValue in
                updateCameraDistance()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(showFilters ? Color.accentColor : Color.secondary)
                    }
                }
            }
            .onSubmit(of: .search) {
                performSearch()
            }
        
        .onChange(of: modelController.deepLinkSearchQuery) { oldValue, newValue in
            if let query = newValue {
                searchText = query
                modelController.deepLinkSearchQuery = nil
                performSearch()
            }
        }
        .onChange(of: modelController.selectedPlaceChatResultFsqId) { oldValue, newValue in
            if let fsqId = newValue {
                modelController.selectedPlaceChatResultFsqId = nil
                Task {
                    do {
                        let result = try await modelController.fetchPlaceByID(fsqID: fsqId)
                        selectedResult = result
                    } catch {
                        print("Deep link place fetch failed: \(error)")
                    }
                }
            }
        }

    }
    
    private var mapLayer: some View {
        Map(position: $position) {
            ForEach(modelController.placeResults) { result in
                if let lat = result.placeResponse?.latitude, let lon = result.placeResponse?.longitude {
                    Marker(result.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tag(result.id)
                }
            }
        }
        .menuIndicator(.visible)
        .mapControls {
            MapPitchToggle()
            MapUserLocationButton()
            MapCompass()
        }
        .mapStyle(.imagery)
        .onMapCameraChange(frequency: .continuous) { context in
            lastedCameraDistance = context.camera.distance
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            if !isSearching {
                withAnimation {
                    showSearchHere = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var searchHereOverlay: some View {
        ZStack(alignment: .top) {
            if showSearchHere {
                Button {
                    performSearchHere()
                } label: {
                    Label("Search Here", systemImage: "arrow.clockwise")
                        .font(.caption.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.thickMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 4)
                }
                .padding(.top, 100)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(1)
            }
        }
    }
    
    private var searchInterface: some View {
        HStack() {
            if (isSearchFieldFocused || !searchText.isEmpty) && modelController.placeResults.isEmpty && !isSearching {
                suggestionsContainer
            }
            // Quick Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCategories, id: \.self) { category in
                        Button {
                            searchText = category
                            performSearch()
                        } label: {
                            Text(category)
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        .glassEffect()
                    }
                }
                .searchable(text: $searchText, isPresented: $isSearching, placement:.navigationBarDrawer(displayMode: .always), prompt: "Search your world...")
                .searchToolbarBehavior(.minimize)

            }
        }
    }
    

    
    private var suggestionsContainer: some View {
        VStack {
            suggestionsList
                .frame(maxHeight: 300)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var resultsDrawer: some View {
        if !modelController.placeResults.isEmpty {
            ResultsDrawer(results: modelController.placeResults, cacheManager: cacheManager, modelController: modelController) { result in
                selectedResult = result
            }
            .transition(.move(edge: .bottom))
        }
    }

    private func updateCameraDistance() {
        let center = modelController.selectedDestinationLocationChatResult.location.coordinate
        withAnimation {
            position = .camera(
                MapCamera(
                    centerCoordinate: center,
                    distance: searchRadius * 1000 * 2.5
                )
            )
        }
    }
    
    private func updateSearchCenter() {
        Task {
            do {
                if let placemark = try await modelController.locationService.lookUpLocationName(name: locationQuery).first,
                   let location = placemark.location {
                    modelController.selectedDestinationLocationChatResult = LocationResult(
                        locationName: placemark.name ?? locationQuery,
                        location: location,
                        formattedAddress: placemark.locality
                    )
                    updateCameraDistance()
                }
            } catch {
                print("Location lookup failed: \(error)")
            }
        }
    }
    
    private func performSearchHere() {
        showSearchHere = false
        if let dist = lastedCameraDistance {
            let calculatedRadius = dist / 1000.0 / 2.0
            searchRadius = min(max(calculatedRadius, 1.0), 200.0)
        }
        
        if let camera = position.camera {
            let center = camera.centerCoordinate
            modelController.selectedDestinationLocationChatResult = LocationResult(
                locationName: "Map PIN",
                location: CLLocation(latitude: center.latitude, longitude: center.longitude)
            )
        } else if let region = position.region {
             let center = region.center
             modelController.selectedDestinationLocationChatResult = LocationResult(
                locationName: "Map Area",
                location: CLLocation(latitude: center.latitude, longitude: center.longitude)
            )
        }
        
        performSearch()
    }

    @ViewBuilder
    private var suggestionsList: some View {
        List {
            // Integrated Favorites Section
            if !cacheManager.allCachedResults.isEmpty {
                Section("Favorites") {
                    ForEach(cacheManager.allCachedResults) { result in
                        Button {
                           let isPlace = result.categoricalChatResults.first?.placeResponse != nil
                           if isPlace {
                               Task {
                                   searchText = result.parentCategory
                                   performSearch()
                               }
                           } else {
                               searchText = result.parentCategory
                               performSearch()
                           }
                        } label: {
                            HStack {
                                let isPlace = result.categoricalChatResults.first?.placeResponse != nil
                                Text(result.icon.isEmpty ? (isPlace ? "📍" : "❤️") : result.icon)
                                VStack(alignment: .leading) {
                                    Text(result.parentCategory)
                                        .foregroundStyle(.primary)
                                    Text(isPlace ? "Place" : "Category")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            if !filteredIndustries.isEmpty {
                Section("Industries") {
                    ForEach(filteredIndustries, id: \.identity) { industry in
                        Button {
                            searchText = industry.parentCategory
                            performSearch()
                        } label: {
                            Label(industry.parentCategory, systemImage: "tag.fill")
                        }
                    }
                }
            }
            
            if !filteredTastes.isEmpty {
                Section("Tastes") {
                    ForEach(filteredTastes, id: \.identity) { taste in
                        Button {
                            searchText = taste.parentCategory
                            performSearch()
                        } label: {
                            Label(taste.parentCategory, systemImage: "sparkles")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        searchTask?.cancel()
        isSearching = true
        searchTask = Task {
            do {
                let currentDestination = modelController.selectedDestinationLocationChatResult
                let (intentKind, enrichedIntent) = try await modelController.assistiveHostDelegate.determineIntentEnhanced(for: searchText, override: nil)
                let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: searchText, filters: ["distance": String(format: "%.0f", searchRadius)], enrichedIntent: enrichedIntent)
                
                let request = IntentRequest(
                    caption: searchText,
                    intentType: intentKind,
                    rawParameters: queryParameters?.mapValues { AnySendable($0 as Sendable) }
                )
                let context = IntentContext(destination: currentDestination)
                
                let intent = AssistiveChatHostIntent(request: request, context: context)
                try await modelController.searchIntent(intent: intent)
                await MainActor.run { isSearching = false }
            } catch {
                print("Search failed: \(error)")
                await MainActor.run { isSearching = false }
            }
        }
    }
}


struct FavoritesView: View {
    var cacheManager: CloudCacheManager
    var modelController: DefaultModelController
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(cacheManager.allCachedResults) { result in
                    HStack {
                        Text(result.icon.isEmpty ? "📍" : result.icon)
                        VStack(alignment: .leading) {
                            Text(result.parentCategory)
                                .font(.headline)
                            Text(result.list)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let item = cacheManager.allCachedResults[index]
                            try? await SearchSavedViewModel.shared.removeSelectedItem(selectedSavedResult: item.identity, cacheManager: cacheManager, modelController: modelController)
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct TogglePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.white.opacity(0.8))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct ResultsDrawer: View {
    let results: [ChatResult]
    let cacheManager: CloudCacheManager
    let modelController: DefaultModelController
    let onSelect: (ChatResult) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(results) { result in
                    PlaceCard(result: result)
                        .onTapGesture { onSelect(result) }
                        .contextMenu {
                            Button {
                                Task {
                                    await SearchSavedViewModel.shared.addPlace(parent: result.id, rating: 5, cacheManager: cacheManager, modelController: modelController)
                                }
                            } label: {
                                Label("Love this", systemImage: "heart.fill")
                            }
                            
                            Button {
                                Task {
                                    await SearchSavedViewModel.shared.addPlace(parent: result.id, rating: 3, cacheManager: cacheManager, modelController: modelController)
                                }
                            } label: {
                                Label("Save", systemImage: "bookmark")
                            }
                        }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}

struct PlaceCard: View {
    let result: ChatResult
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let firstPhoto = result.placeDetailsResponse?.photoResponses?.first {
                AsyncImage(url: firstPhoto.photoUrl()) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                }
                .frame(width: 200, height: 120)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 200, height: 120)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let address = result.placeResponse?.formattedAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    if let rating = result.placeDetailsResponse?.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2.bold())
                        }
                    }
                    if let price = result.placeDetailsResponse?.price {
                        Text(String(repeating: "$", count: price))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
        .frame(width: 200)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
