import SwiftUI
import CoreLocation
import MapKit
import CallKit
import NukeUI
#if canImport(UIKit)
import UIKit
#endif

struct PlaceAboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) var sizeClass
    var searchSavedViewModel:SearchSavedViewModel
    var chatModel:ChatResultViewModel
    var cacheManager:CloudCacheManager
    var modelController:DefaultModelController
    @Binding  var tabItem: Int
    @State var mutableTastes: [String] = []
    @State private var presentingPopover: Bool = false
    @State private var isPresentingShareSheet:Bool = false
    static let defaultPadding: CGFloat = 8
    static let mapFrameConstraint: Double = 50000
    static let cornerRadius: CGFloat = 16
    public let selectedResult:ChatResult
    @State private var viewModel = PlaceAboutViewModel()
    
    @Namespace var topID
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        // Precompute selected result and unwrap step-by-step to help the type-checker
                        
                        let liveResult = modelController.selectedPlaceChatResultFsqId
                            .flatMap { modelController.placeChatResult(with: $0) }
                            ?? selectedResult
                        let placeResponse = liveResult.placeResponse
                        let placeDetailsResponse = liveResult.placeDetailsResponse
                        let placeSnapshot = liveResult.makePlaceSnapshot(concept: nil)

                        if let placeResponse,
                           let placeDetailsResponse {

                            // Title and Map precomputed values
                            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                            let title = placeResponse.name

                            PhotosCarousel(isRefreshing: modelController.isRefreshingPlaces, photoResponses: placeDetailsResponse.photoResponses, geoSize: geo.size)
                                .padding(16)

                            InfoSection(placeResponse: placeDetailsResponse) {
                                tabItem = 1
                            }
                            .padding()

                            ActionButtonsRow(cacheManager:cacheManager,sizeClass: sizeClass, title: title, resultId: selectedResult.id, placeDetailsResponse: placeDetailsResponse, openURL: openURL, onSave: {
                                await viewModel.toggleSavePlace(resultId: selectedResult.id, cacheManager: cacheManager, modelController: modelController)
                            })
                            .padding(.horizontal, 16)

                            RatingsPriceShareRow(sizeClass: sizeClass, placeDetailsResponse: placeDetailsResponse, onShowReviews: { tabItem = 3 }, presentingPopover: $presentingPopover, isPresentingShareSheet: $isPresentingShareSheet) {
                                
                                    let items: [Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.formattedAddress]
                                    #if os(macOS)
                                    ActivityViewController(activityItems: items, isPresentingShareSheet: $isPresentingShareSheet)
                                        .presentationDetents([.medium])
                                        .presentationDragIndicator(.visible)
                                        .presentationCompactAdaptation(.sheet)
                                    #else
                                    ActivityViewController(activityItems: items, applicationActivities:[], isPresentingShareSheet: $isPresentingShareSheet)
                                        .presentationDetents([.medium])
                                        .presentationDragIndicator(.visible)
                                        .presentationCompactAdaptation(.sheet)
                                    #endif
                            }
                            .padding(.horizontal, 16)

                            RelatedPlacesSection(relatedPlaceResults: modelController.relatedPlaceResults) { relatedPlace in
                                handlePlaceTap(relatedPlace)
                            }
                            .padding(.horizontal,16)

                            if let tastes = placeDetailsResponse.tastes, !tastes.isEmpty {
                                Divider()
                                    .padding(.vertical, 24)
                                TastesSection(sizeClass: sizeClass, mutableTastes: $mutableTastes, cachedTastesContains: { taste in
                                    cacheManager.cachedTastes(contains: taste)
                                }, fetchCachedTasteResult: { taste in
                                    modelController.cachedTasteResultTitle(taste)
                                }, addTaste: { taste in
                                    await viewModel.addTaste(title: taste, cacheManager: cacheManager, modelController: modelController)
                                }, removeTaste: { parent in
                                    await viewModel.removeTaste(parent: parent, cacheManager: cacheManager, modelController: modelController)
                                })
                                .padding(.horizontal,16)
                                .onChange(of: placeDetailsResponse.tastes) { _, newTastes in
                                    // Keep local state in sync with the model data.
                                    mutableTastes = newTastes ?? []
                                }
                                .onAppear { mutableTastes = placeDetailsResponse.tastes ?? [] }
                            }

                            Divider()
                                .padding(.vertical, 12)
                            MapSection(title: title, coordinate: placeCoordinate.coordinate, minHeight: geo.size.height / 2.0)
                                .padding(.horizontal,16)
                        } else if let placeSnapshot {
                            SnapshotPlaceAbout(snapshot: placeSnapshot, geoSize: geo.size)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        } else {
                            VStack {
                                Spacer()
                                ProgressView {
                                    Text(modelController.fetchMessage)
                                }
                                .progressViewStyle(.linear)
                                .padding()
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handlePlaceTap(_ result: ChatResult) {
        // Kick off the place search intent using the DefaultModelController
        Task { @MainActor in
            do {
                
                let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: result.title, filters: searchSavedViewModel.filters)
                
                // create a new AssistiveChatHostIntent from the chatresult
                let intent = AssistiveChatHostIntent(caption: result.title, intent: .Place, selectedPlaceSearchResponse: result.placeResponse, selectedPlaceSearchDetails: nil, placeSearchResponses:[result.placeResponse!], selectedDestinationLocation: modelController.selectedDestinationLocationChatResult, placeDetailsResponses: nil, queryParameters: queryParameters)
                
                try await modelController.searchIntent(intent: intent)
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
            }
        }
    }
}

private struct SnapshotPlaceAbout: View {
    let snapshot: KnowMapsPlaceSnapshot
    let geoSize: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SnapshotPhotosCarousel(photoURLs: photoURLs, geoSize: geoSize)

            if let concept = snapshot.concept, !concept.isEmpty {
                Text(concept)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if let summary = snapshot.summary, !summary.isEmpty {
                Text(summary)
            }

            if let hoursText = snapshot.hoursText, !hoursText.isEmpty {
                Label(hoursText, systemImage: "clock")
                    .labelStyle(.titleOnly)
                    .foregroundStyle(.secondary)
            }

            if let address = addressText, !address.isEmpty {
                Label(address, systemImage: "mappin")
                    .labelStyle(.titleOnly)
            }

            HStack(spacing: 12) {
                if let rating = snapshot.rating {
                    Text(String(format: "%.1f", rating))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                }
                if let priceTier = snapshot.priceTier {
                    Text(priceToString(priceTier))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                }
            }

            if !snapshot.tastes.isEmpty {
                Text(snapshot.tastes.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoURLs: [URL] {
        var seen = Set<String>()
        let raw = [snapshot.heroPhotoURL] + snapshot.photoURLs
        return raw
            .compactMap { $0 }
            .compactMap { urlString in
                guard seen.insert(urlString).inserted else { return nil }
                return URL(string: urlString)
            }
    }

    private var addressText: String? {
        if let formatted = snapshot.location.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
           !formatted.isEmpty {
            return formatted
        }

        let parts = [
            snapshot.location.neighborhood,
            snapshot.location.locality,
            snapshot.location.regionCode,
            snapshot.location.countryCode
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private func priceToString(_ price: Int) -> String {
        switch price {
        case 1:
            return "$"
        case 2:
            return "$$"
        case 3:
            return "$$$"
        case 4:
            return "$$$$"
        default:
            return "\(price)"
        }
    }
}

private struct SnapshotPhotosCarousel: View {
    let photoURLs: [URL]
    let geoSize: CGSize

    var body: some View {
        Group {
            if photoURLs.isEmpty {
                Image(systemName: "photo")
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                    .frame(maxWidth: geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(photoURLs, id: \.absoluteString) { url in
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image.resizable()
                                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                                        .scaledToFit()
                                        .frame(maxWidth: geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                                } else if state.error != nil {
                                    Image(systemName: "photo")
                                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                                        .frame(maxWidth: geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                                } else {
                                    ProgressView()
                                        .frame(maxWidth: geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                                        .padding()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PhotosCarousel: View {
    let isRefreshing: Bool
    let photoResponses: [PlacePhotoResponse]?
    let geoSize: CGSize

    var body: some View {
        Group {
            if isRefreshing {
                ScrollView(.horizontal) {
                    Image(systemName: "photo")
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                        .frame(maxWidth:geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                }
            } else if let photoResponses, !photoResponses.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack {
                        ForEach(photoResponses) { photoResponse in
                            if let photoURL = photoResponse.photoUrl() {
                                LazyImage(url: photoURL) { state in
                                    if let image = state.image {
                                        image.resizable()
                                            .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                                            .scaledToFit()
                                            .frame(maxWidth:geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                                    } else if state.error != nil {
                                        Image(systemName: "photo")
                                            .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                                            .frame(maxWidth:geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                                    } else {
                                        ProgressView()
                                            .frame(maxWidth:geoSize.width / 2.0, maxHeight: geoSize.height / 2.0)
                                            .padding()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct InfoSection: View {
    let placeResponse: PlaceDetailsResponse
    let onTapAddress: () -> Void

    init(placeResponse: PlaceDetailsResponse, onTapAddress: @escaping () -> Void) {
        self.placeResponse = placeResponse
        self.onTapAddress = onTapAddress
    }

    var body: some View {
        VStack {
            Text(placeResponse.searchResponse.categories.joined(separator: ", ")).italic()
                .padding(PlaceAboutView.defaultPadding)
            if let description = placeResponse.description, !description.isEmpty {
                Text(description).padding(PlaceAboutView.defaultPadding)
            }
            if let price = placeResponse.price {
                Text(priceToString(price: price))
                    .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                    .padding(PlaceAboutView.defaultPadding)
            }
            Label(placeResponse.searchResponse.formattedAddress, systemImage: "mappin")
                .multilineTextAlignment(.center)
                .labelStyle(.titleOnly)
                .padding(PlaceAboutView.defaultPadding)
                .onTapGesture { onTapAddress() }
        }
    }
    
    // Helper to convert price into a string
    func priceToString(price: Int) -> String {
        switch price {
        case 1:
            return "$"
        case 2:
            return "$$"
        case 3:
            return "$$$"
        case 4:
            return "$$$$"
        default:
            return "\(price)"
        }
    }
}

private struct ActionButtonsRow: View {
    let cacheManager:CloudCacheManager
    let sizeClass: UserInterfaceSizeClass? // This is fine
    let title: String
    let resultId: String
    let placeDetailsResponse: PlaceDetailsResponse
    let openURL: OpenURLAction
    let onSave: () async -> Void

    var body: some View {
        HStack {
            Spacer() // This is fine
            Button {
                Task(priority: .userInitiated) { await onSave() }
            } label: {
                let isSaved = cacheManager.cachedPlaces(contains: title)
                Group {
                    Label(isSaved ? "Delete" : "Add to List", systemImage: isSaved ? "minus.circle" : "plus.circle")
                        .labelStyle(.titleAndIcon)
                        .padding(PlaceAboutView.defaultPadding)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
            .padding(PlaceAboutView.defaultPadding)
#if !os(visionOS)
//.buttonStyle(.glass)
#endif

#if os(visionOS)
            .hoverEffect(.lift)
#endif

            if let tel = placeDetailsResponse.tel {
                Button {
                    if let url = PlaceAboutViewModel.getCallURL(tel: tel) { openURL(url) }
                } label: {
                    Group {
                        if sizeClass == .compact {
                            Label(tel, systemImage: "phone")
                                .labelStyle(.iconOnly)
                                .padding(PlaceAboutView.defaultPadding)
                        } else {
                            Label(tel, systemImage: "phone")
                                .labelStyle(.titleAndIcon)
                                .padding(PlaceAboutView.defaultPadding)
                        }
                    }

                }
                .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                .padding(PlaceAboutView.defaultPadding)
#if !os(visionOS)
//.buttonStyle(.glass)
#endif
                
#if os(visionOS)
                .hoverEffect(.lift)
#endif
            }

            if let website = placeDetailsResponse.website, let url = PlaceAboutViewModel.getWebsiteURL(website: website) {
                Button { openURL(url) } label: {
                    Group {
                        if sizeClass == .compact {
                            Label("Visit website", systemImage: "link")
                                .labelStyle(.iconOnly)
                                .padding(PlaceAboutView.defaultPadding)
                        } else {
                            Label("Visit website", systemImage: "link")
                                .labelStyle(.titleAndIcon)
                                .padding(PlaceAboutView.defaultPadding)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                .padding(PlaceAboutView.defaultPadding)
#if !os(visionOS)
//.buttonStyle(.glass)
#endif
#if os(visionOS)
                .hoverEffect(.lift)
#endif
            }
            Spacer()
        }
    }
}

private struct RatingsPriceShareRow<ShareSheetContent: View>: View {
    let sizeClass: UserInterfaceSizeClass?
    let placeDetailsResponse: PlaceDetailsResponse
    let onShowReviews: () -> Void
    @Binding var presentingPopover: Bool
    @Binding var isPresentingShareSheet: Bool
    let shareSheetContent: ShareSheetContent

    init(sizeClass: UserInterfaceSizeClass?, placeDetailsResponse: PlaceDetailsResponse, onShowReviews: @escaping () -> Void, presentingPopover: Binding<Bool>, isPresentingShareSheet: Binding<Bool>, @ViewBuilder shareSheetContent: () -> ShareSheetContent) {
        self.sizeClass = sizeClass
        self.placeDetailsResponse = placeDetailsResponse
        self.onShowReviews = onShowReviews
        self._presentingPopover = presentingPopover
        self._isPresentingShareSheet = isPresentingShareSheet
        self.shareSheetContent = shareSheetContent()
    }

    var body: some View {
        HStack {
            Spacer()
            if placeDetailsResponse.rating > 0 {
                Button { onShowReviews() } label: {
                    Label(PlacesList.formatter.string(from: NSNumber(value: placeDetailsResponse.rating)) ?? "0", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .padding(PlaceAboutView.defaultPadding)

                }
                .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                .padding(PlaceAboutView.defaultPadding)
#if !os(visionOS)
//.buttonStyle(.glass)
#endif
#if os(visionOS)
                .hoverEffect(.lift)
#endif
            }
#if os(iOS) || os(visionOS)
            Button { presentingPopover.toggle() } label: {
                Group {
                    if sizeClass == .compact {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .padding(PlaceAboutView.defaultPadding)
                    } else {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.titleAndIcon)
                            .padding(PlaceAboutView.defaultPadding)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
            .padding(PlaceAboutView.defaultPadding)
            .sheet(isPresented: $presentingPopover) {
                shareSheetContent
            }
#if !os(visionOS)
//.buttonStyle(.glass)
#endif
#if os(visionOS)
            .hoverEffect(.lift)
#endif

#endif
            Spacer()
        }
    }
}

private struct RelatedPlacesSection: View {
    let relatedPlaceResults: [ChatResult]
    let onTap: (ChatResult) -> Void

    var body: some View {
        Divider()
            .padding(.vertical, 24)
        Section {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(relatedPlaceResults) { relatedPlace in
                        VStack {
                            Text(relatedPlace.title).bold()
                            if let neighborhood = relatedPlace.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                Text(neighborhood).italic()
                            } else if let locality = relatedPlace.placeResponse?.locality {
                                Text(locality).italic()
                            }
                        }
                        .padding(PlaceAboutView.defaultPadding)
                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                        .onTapGesture { onTap(relatedPlace) }
#if !os(visionOS)
//                        .glassEffect(.regular, in: .rect(cornerRadius: PlaceAboutView.cornerRadius))
#endif
                        
#if os(visionOS)
                        .hoverEffect(.lift)
#endif
                        
                    }
                }
            }
        } header: {
            Text("Related Places").font(.headline)
        }
    }
}

private struct TastesSection: View {
    let sizeClass: UserInterfaceSizeClass?
    @Binding var mutableTastes: [String]
    let cachedTastesContains: (String) -> Bool
    let fetchCachedTasteResult: (String) -> CategoryResult?
    let addTaste: @Sendable (String) async -> Void
    let removeTaste: @Sendable (CategoryResult) async -> Void

    var body: some View {
        Section {
            let gridItems = Array(repeating: GridItem(.flexible(), spacing: PlaceAboutView.defaultPadding), count: sizeClass == .compact ? 2 : 3)
            LazyVGrid(columns: gridItems, alignment: .leading, spacing: 8) {
                ForEach($mutableTastes, id: \.self) { taste in
                    let isSaved = cachedTastesContains(taste.wrappedValue)
                    Button {
                        if isSaved {
                            if let cachedTasteResult = fetchCachedTasteResult(taste.wrappedValue) {
                                Task(priority: .userInitiated) { await removeTaste(cachedTasteResult) }
                            }
                        } else {
                            Task(priority: .userInitiated) { await addTaste(taste.wrappedValue) }
                        }
                    } label: {
                        HStack {
                            Label("Save", systemImage: isSaved ? "minus.circle" : "plus.circle")
                                .labelStyle(.iconOnly)
                                .padding(PlaceAboutView.defaultPadding)
                            Text(taste.wrappedValue)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Group {
#if !os(visionOS)
                            Color.clear
//                                .glassEffect(.regular, in: .rect(cornerRadius: PlaceAboutView.cornerRadius))
#endif
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
#if os(visionOS)
                    .hoverEffect(.lift)
#endif
                }
            }
        } header: {
            Text("Features").font(.headline)
        }
    }
}

private struct MapSection: View {
    let title: String
    let coordinate: CLLocationCoordinate2D
    let minHeight: CGFloat

    var body: some View {
        Section {
            Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 5000, maximumDistance: 250000), interactionModes: [.zoom, .rotate]) {
                Marker(title, coordinate: coordinate)
            }
            .mapStyle(.hybrid)
            .frame(minHeight: minHeight)
            .cornerRadius(PlaceAboutView.cornerRadius)
        }
    }
}
