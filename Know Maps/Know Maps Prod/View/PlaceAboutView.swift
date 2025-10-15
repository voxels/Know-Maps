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
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding  var tabItem: Int
    @State var mutableTastes: [String] = []
    @State private var presentingPopover: Bool = false
    @State private var isPresentingShareSheet:Bool = false
    static let defaultPadding: CGFloat = 8
    static let mapFrameConstraint: Double = 50000
    static let cornerRadius: CGFloat = 16
    
    var viewModel: PlaceAboutViewModel = .init()
    
    @Namespace var topID
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        // Precompute selected result and unwrap step-by-step to help the type-checker
                        let selectedId = modelController.selectedPlaceChatResult
                        let result = selectedId.flatMap { modelController.placeChatResult(for: $0) }
                        let placeResponse = result?.placeResponse
                        let placeDetailsResponse = result?.placeDetailsResponse

                        if let resultId = selectedId,
                           let placeResponse,
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

                            ActionButtonsRow(cacheManager:cacheManager,sizeClass: sizeClass, title: title, resultId: resultId, placeDetailsResponse: placeDetailsResponse, openURL: openURL, onSave: {
                                await viewModel.toggleSavePlace(resultId: resultId, cacheManager: cacheManager, modelController: modelController)
                            })
                            .padding(.horizontal, 16)

                            RatingsPriceShareRow(sizeClass: sizeClass, placeDetailsResponse: placeDetailsResponse, onShowReviews: { tabItem = 3 }, presentingPopover: $presentingPopover, isPresentingShareSheet: $isPresentingShareSheet) {
                                if let result = modelController.placeChatResult(for: resultId), let placeDetailsResponse = result.placeDetailsResponse  {
                                    let items: [Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.address]
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
                            }
                            .padding(.horizontal, 16)

                            RelatedPlacesSection(relatedPlaceResults: modelController.relatedPlaceResults) { relatedPlace in
                                Task { @MainActor in
                                    do {
                                        try await modelController.resetPlaceModel()
                                        try await chatModel.didSearch(
                                            caption: relatedPlace.title,
                                            selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult,
                                            filters: searchSavedViewModel.filters,
                                            cacheManager: cacheManager,
                                            modelController: modelController
                                        )
                                        await MainActor.run {
                                            modelController.isRefreshingPlaces = false
                                        }
                                    } catch {
                                        modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                                    }
                                }
                            }
                            .padding(.horizontal,16)

                            if let tastes = placeDetailsResponse.tastes, !tastes.isEmpty {
                                Divider()
                                    .padding(.vertical, 24)
                                TastesSection(sizeClass: sizeClass, mutableTastes: $mutableTastes, cachedTastesContains: { taste in
                                    cacheManager.cachedTastes(contains: taste)
                                }, fetchCachedTasteResult: { taste in
                                    modelController.cachedTasteResult(title: taste, cacheManager: cacheManager)
                                }, addTaste: { taste in
                                    await viewModel.addTaste(title: taste, cacheManager: cacheManager, modelController: modelController)
                                }, removeTaste: { parent in
                                    await viewModel.removeTaste(parent: parent, cacheManager: cacheManager, modelController: modelController)
                                })
                                .padding(.horizontal,16)
                                .task {
                                    if let tastes = placeDetailsResponse.tastes {
                                        mutableTastes = tastes
                                    }
                                }
                                Divider()
                                    .padding(.vertical, 12)
                                MapSection(title: title, coordinate: placeCoordinate.coordinate, minHeight: geo.size.height / 2.0)
                                    .padding(.horizontal,16)
                            }
                        } else {
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
                        .frame(maxWidth:.infinity, maxHeight: .infinity)
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
    let sizeClass: UserInterfaceSizeClass?
    let title: String
    let resultId: UUID
    let placeDetailsResponse: PlaceDetailsResponse
    let openURL: OpenURLAction
    let onSave: () async -> Void

    var body: some View {
        HStack {
            Spacer()
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
#if os(visionOS)
.background(.ultraThinMaterial)
#else
.buttonStyle(.glass)
#endif

#if os(visionOS)
            .hoverEffect(.lift)
#endif

            if let tel = placeDetailsResponse.tel {
                Button {
                    if let url = getCallURL(tel: tel) { openURL(url) }
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
#if os(visionOS)
.background(.ultraThinMaterial)
#else
.buttonStyle(.glass)
#endif
#if os(visionOS)
                .hoverEffect(.lift)
#endif
            }

            if let website = placeDetailsResponse.website, let url = getWebsiteURL(website: website) {
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
#if os(visionOS)
.background(.ultraThinMaterial)
#else
.buttonStyle(.glass)
#endif
#if os(visionOS)
                .hoverEffect(.lift)
#endif
            }
            Spacer()
        }
    }

    private func getCallURL(tel: String) -> URL? { PlaceAboutViewModel().getCallURL(tel: tel) }
    private func getWebsiteURL(website: String) -> URL? { PlaceAboutViewModel().getWebsiteURL(website: website) }
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
#if os(visionOS)
.background(.ultraThinMaterial)
#else
.buttonStyle(.glass)
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
#if os(visionOS)
.background(.ultraThinMaterial)
#else
.buttonStyle(.glass)
#endif
#if os(visionOS)
            .hoverEffect(.lift)
#endif
            .sheet(isPresented: $presentingPopover) {
                shareSheetContent
            }
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
#if !os(visionOS)
                        .glassEffect(.regular, in: .rect(cornerRadius: PlaceAboutView.cornerRadius))
#else
                        .background(.ultraThinMaterial)
#endif
                        .clipShape(RoundedRectangle(cornerRadius: PlaceAboutView.cornerRadius, style: .continuous))
#if os(visionOS)
                        .hoverEffect(.lift)
#endif
                        .onTapGesture { onTap(relatedPlace) }
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
                                .glassEffect(.regular, in: .rect(cornerRadius: PlaceAboutView.cornerRadius))
#else
                            Color.clear.background(.ultraThinMaterial)
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

