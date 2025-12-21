//
//  PlaceView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/18/23.
//

import SwiftUI
import CoreLocation
import MapKit
import NukeUI

public struct PlaceView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public var searchSavedViewModel:SearchSavedViewModel
    public var chatModel:ChatResultViewModel
    public var cacheManager:CloudCacheManager
    public var modelController:DefaultModelController
    public let selectedResult:ChatResult

    @State private var isFetchingDetails: Bool = false
    @State private var didAttemptDetailFetch: Bool = false
    @State private var showLookAround: Bool = false
    @State private var isPresentingShareSheet: Bool = false
    private let aboutViewModel = PlaceAboutViewModel()
    @StateObject private var directionsModel: PlaceDirectionsViewModel

    public init(
        searchSavedViewModel: SearchSavedViewModel = .shared,
        chatModel: ChatResultViewModel = .sharedInstance,
        cacheManager: CloudCacheManager,
        modelController: DefaultModelController,
        selectedResult: ChatResult
    ) {
        self.searchSavedViewModel = searchSavedViewModel
        self.chatModel = chatModel
        self.cacheManager = cacheManager
        self.modelController = modelController
        self.selectedResult = selectedResult
        self._directionsModel = StateObject(wrappedValue: PlaceDirectionsViewModel(rawLocationIdent: ""))
    }

    public var body: some View {
        let fallbackFsqId = resolvedFsqId(from: selectedResult)
        let selectedFsqId = modelController.selectedPlaceChatResultFsqId ?? fallbackFsqId
        let liveResult = modelController.placeChatResult(with: selectedFsqId) ?? selectedResult
        let snapshot = liveResult.makePlaceSnapshot(concept: nil)
        let title = snapshot?.title ?? liveResult.title
        let isLoadingDetails = isFetchingDetails || (!didAttemptDetailFetch && liveResult.placeDetailsResponse == nil)
        let showSkeleton = isLoadingDetails && liveResult.placeDetailsResponse == nil
        let address = resolvedAddress(details: liveResult.placeDetailsResponse, snapshot: snapshot, placeResponse: liveResult.placeResponse)
        let destination = destinationCoordinate(
            details: liveResult.placeDetailsResponse,
            snapshot: snapshot,
            placeResponse: liveResult.placeResponse,
            recommendedPlaceResponse: liveResult.recommendedPlaceResponse
        )
        let destinationKey = destination.map { "\($0.latitude),\($0.longitude)" } ?? ""
        let tastes = liveResult.placeDetailsResponse?.tastes ?? snapshot?.tastes ?? []

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let address, !address.isEmpty {
                        Text(address)
                            .foregroundStyle(.secondary)
                    }
                    if showSkeleton {
                        PlaceFeedSkeletonBar()
                    } else if isLoadingDetails {
                        ProgressView { Text("Loading place details…") }
                            .progressViewStyle(.linear)
                    }
                }

                if showSkeleton {
                    PlaceFeedSkeleton(isCompact: horizontalSizeClass == .compact)
                } else {
                    PlaceFeedHeroPhotos(
                        title: title,
                        isRefreshing: modelController.isRefreshingPlaces || isLoadingDetails,
                        photoURLs: makeHeroPhotoURLs(details: liveResult.placeDetailsResponse, snapshot: snapshot)
                    )

                    PlaceFeedAboutCard(
                        title: title,
                        snapshot: snapshot,
                        placeResponse: liveResult.placeResponse,
                        placeDetailsResponse: liveResult.placeDetailsResponse,
                        isFetchingDetails: isLoadingDetails
                    )

                    PlaceFeedActionsRow(
                        isCompact: horizontalSizeClass == .compact,
                        title: title,
                        placeDetailsResponse: liveResult.placeDetailsResponse,
                        isSaved: cacheManager.cachedPlaces(contains: title),
                        onToggleSave: {
                            await aboutViewModel.toggleSavePlace(
                                resultId: liveResult.id,
                                cacheManager: cacheManager,
                                modelController: modelController
                            )
                        },
                        onShare: { isPresentingShareSheet = true },
                        openURL: openURL
                    )

                    PlaceFeedDirectionsSection(
                        isCompact: horizontalSizeClass == .compact,
                        title: title,
                        address: address,
                        destinationCoordinate: destination,
                        showLookAround: $showLookAround,
                        model: directionsModel
                    )

                    PlaceFeedTipsList(
                        tips: liveResult.placeDetailsResponse?.tipsResponses,
                        isFetchingDetails: isLoadingDetails
                    )

                    if !modelController.relatedPlaceResults.isEmpty {
                        PlaceFeedRelatedPlaces(
                            relatedPlaceResults: modelController.relatedPlaceResults,
                            onTap: { relatedPlace in
                                handleRelatedPlaceTap(relatedPlace)
                            }
                        )
                    }

                    PlaceFeedTastes(
                        isCompact: horizontalSizeClass == .compact,
                        tastes: tastes,
                        cachedTastesContains: { taste in
                            cacheManager.cachedTastes(contains: taste)
                        },
                        cachedTasteResult: { taste in
                            modelController.cachedTasteResultTitle(taste)
                        },
                        addTaste: { taste in
                            await aboutViewModel.addTaste(title: taste, cacheManager: cacheManager, modelController: modelController)
                        },
                        removeTaste: { parent in
                            await aboutViewModel.removeTaste(parent: parent, cacheManager: cacheManager, modelController: modelController)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle(title)
        .sheet(isPresented: $isPresentingShareSheet) {
            let shareText = resolvedShareText(
                details: liveResult.placeDetailsResponse,
                snapshot: snapshot,
                placeResponse: liveResult.placeResponse
            )
            let items: [Any] = [shareText]
            #if os(macOS)
            ActivityViewController(activityItems: items, isPresentingShareSheet: $isPresentingShareSheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCompactAdaptation(.sheet)
            #else
            ActivityViewController(activityItems: items, applicationActivities: [], isPresentingShareSheet: $isPresentingShareSheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCompactAdaptation(.sheet)
            #endif
        }
        .task(id: selectedFsqId) { @MainActor in
            showLookAround = false
            didAttemptDetailFetch = false
            directionsModel.lookAroundScene = nil
            directionsModel.route = nil
            directionsModel.polyline = nil
            directionsModel.chatRouteResults = nil

            modelController.setSelectedPlaceChatResult(selectedFsqId)
            await fetchDetailsIfNeeded(for: selectedFsqId)
            didAttemptDetailFetch = true
        }
        .task(id: destinationKey) { @MainActor in
            guard !destinationKey.isEmpty, let destination else { return }
            await refreshDirections(to: destination)
        }
        .onChange(of: directionsModel.rawTransportType) { newValue in
            switch newValue {
            case .Walking:
                directionsModel.transportType = .walking
            case .Transit:
                directionsModel.transportType = .transit
            case .Automobile:
                directionsModel.transportType = .automobile
            }
        }
        .onChange(of: directionsModel.transportType) { _ in
            guard let destination else { return }
            Task { @MainActor in
                await refreshDirections(to: destination)
            }
        }
        .onChange(of: modelController.selectedDestinationLocationChatResult.id) { _ in
            guard let destination else { return }
            Task { @MainActor in
                await refreshDirections(to: destination)
            }
        }
    }

    // MARK: - Data Resolution

    private func resolvedFsqId(from result: ChatResult) -> String {
        result.placeResponse?.fsqID
            ?? result.recommendedPlaceResponse?.fsqID
            ?? result.placeDetailsResponse?.fsqID
            ?? result.id
    }

    private func destinationCoordinate(
        details: PlaceDetailsResponse?,
        snapshot: KnowMapsPlaceSnapshot?,
        placeResponse: PlaceSearchResponse?,
        recommendedPlaceResponse: RecommendedPlaceSearchResponse?
    ) -> CLLocationCoordinate2D? {
        let candidates: [(Double?, Double?)] = [
            (details?.searchResponse.latitude, details?.searchResponse.longitude),
            (snapshot?.latitude, snapshot?.longitude),
            (placeResponse?.latitude, placeResponse?.longitude),
            (recommendedPlaceResponse?.latitude, recommendedPlaceResponse?.longitude)
        ]

        for (lat, lon) in candidates {
            guard let lat, let lon else { continue }
            if lat == 0, lon == 0 { continue }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        return nil
    }

    private func resolvedAddress(
        details: PlaceDetailsResponse?,
        snapshot: KnowMapsPlaceSnapshot?,
        placeResponse: PlaceSearchResponse?
    ) -> String? {
        if let address = details?.searchResponse.formattedAddress, !address.isEmpty {
            return address
        }
        if let address = snapshot?.location.formattedAddress, !address.isEmpty {
            return address
        }
        if let address = placeResponse?.formattedAddress, !address.isEmpty {
            return address
        }
        return nil
    }

    private func resolvedShareText(
        details: PlaceDetailsResponse?,
        snapshot: KnowMapsPlaceSnapshot?,
        placeResponse: PlaceSearchResponse?
    ) -> String {
        if let website = details?.website, !website.isEmpty {
            return website
        }
        return resolvedAddress(details: details, snapshot: snapshot, placeResponse: placeResponse) ?? ""
    }

    private func makeHeroPhotoURLs(details: PlaceDetailsResponse?, snapshot: KnowMapsPlaceSnapshot?) -> [URL] {
        var seen = Set<String>()

        if let photoResponses = details?.photoResponses, !photoResponses.isEmpty {
            return photoResponses.compactMap { $0.photoUrl() }
        }

        let raw = [snapshot?.heroPhotoURL] + (snapshot?.photoURLs ?? [])
        return raw
            .compactMap { $0 }
            .compactMap { urlString in
                guard seen.insert(urlString).inserted else { return nil }
                return URL(string: urlString)
            }
    }

    // MARK: - Loading

    @MainActor
    private func fetchDetailsIfNeeded(for fsqID: String) async {
        guard !fsqID.isEmpty else { return }

        let result = modelController.placeChatResult(with: fsqID) ?? selectedResult
        guard result.placeDetailsResponse == nil else { return }

        isFetchingDetails = true
        defer { isFetchingDetails = false }
        do {
            try await modelController.fetchPlaceDetailsIfNeeded(for: result)
        } catch {
            modelController.analyticsManager.trackError(
                error: error,
                additionalInfo: ["context": "PlaceView.fetchPlaceDetails"]
            )
        }
    }

    @MainActor
    private func refreshDirections(to destinationCoordinate: CLLocationCoordinate2D) async {
        let sourceLocation = modelController.selectedDestinationLocationChatResult.location
        let destinationLocation = CLLocation(
            latitude: destinationCoordinate.latitude,
            longitude: destinationCoordinate.longitude
        )

        do {
            try await directionsModel.refreshDirections(with: sourceLocation, destination: destinationLocation)
        } catch {
            modelController.analyticsManager.trackError(
                error: error,
                additionalInfo: ["context": "PlaceView.refreshDirections"]
            )
        }
    }

    // MARK: - Navigation

    private func handleRelatedPlaceTap(_ relatedPlace: ChatResult) {
        Task { @MainActor in
            do {
                try await modelController.fetchPlaceDetails(for: relatedPlace)
                if let fsqID = relatedPlace.placeResponse?.fsqID ?? relatedPlace.recommendedPlaceResponse?.fsqID {
                    modelController.selectedPlaceChatResultFsqId = fsqID
                }
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo: ["context": "PlaceView.relatedPlaceTap"])
            }
        }
    }
}

// MARK: - Feed Sections

private struct PlaceFeedSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedSkeletonBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedSkeleton: View {
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PlaceFeedSkeletonBox(height: 240, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 12) {
                PlaceFeedSectionHeader(title: "About")
                PlaceFeedSkeletonTextBlock(lines: 3)
                HStack(spacing: 12) {
                    PlaceFeedSkeletonPill(width: 76, height: 28)
                    PlaceFeedSkeletonPill(width: 52, height: 28)
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PlaceFeedSectionHeader(title: "Actions")
                HStack(spacing: 12) {
                    PlaceFeedSkeletonBox(height: 44, cornerRadius: 12)
                    PlaceFeedSkeletonBox(height: 44, cornerRadius: 12)
                    PlaceFeedSkeletonBox(height: 44, cornerRadius: 12)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PlaceFeedSectionHeader(title: "Directions")
                PlaceFeedSkeletonBox(height: 320, cornerRadius: 16)
                PlaceFeedSkeletonBox(height: 44, cornerRadius: 12)
                HStack(spacing: 12) {
                    PlaceFeedSkeletonPill(width: 84, height: 36)
                    PlaceFeedSkeletonPill(width: 132, height: 36)
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 10) {
                    PlaceFeedSkeletonBox(height: 56, cornerRadius: 12)
                    PlaceFeedSkeletonBox(height: 56, cornerRadius: 12)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PlaceFeedSectionHeader(title: "Tips")
                VStack(alignment: .leading, spacing: 10) {
                    PlaceFeedSkeletonBox(height: 72, cornerRadius: 14)
                    PlaceFeedSkeletonBox(height: 72, cornerRadius: 14)
                    PlaceFeedSkeletonBox(height: 72, cornerRadius: 14)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PlaceFeedSectionHeader(title: "Features")
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: isCompact ? 2 : 3)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(0..<(isCompact ? 6 : 9), id: \.self) { _ in
                        PlaceFeedSkeletonBox(height: 44, cornerRadius: 14)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedSkeletonTextBlock: View {
    let lines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlaceFeedSkeletonLine(fraction: 1, height: 14)
            PlaceFeedSkeletonLine(fraction: 1, height: 14)
            PlaceFeedSkeletonLine(fraction: 1, height: 14)            
        }
    }
}

private struct PlaceFeedSkeletonLine: View {
    let fraction: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: geo.size.width * max(0, min(fraction, 1)), height: height)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
    }
}

private struct PlaceFeedSkeletonPill: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .frame(width: width, height: height)
    }
}

private struct PlaceFeedSkeletonBox: View {
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.14))
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

private struct PlaceFeedHeroPhotos: View {
    let title: String
    let isRefreshing: Bool
    let photoURLs: [URL]

    var body: some View {
        GeometryReader { geo in
            Group {
                if isRefreshing {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.secondary.opacity(0.12))
                        ProgressView()
                    }
                } else if photoURLs.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.secondary.opacity(0.12))
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(photoURLs, id: \.absoluteString) { url in
                                LazyImage(url: url) { state in
                                    if let image = state.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width * 0.82, height: geo.size.height)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    } else if state.error != nil {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.secondary.opacity(0.12))
                                            Image(systemName: "photo")
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: geo.size.width * 0.82, height: geo.size.height)
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.secondary.opacity(0.10))
                                            ProgressView()
                                        }
                                        .frame(width: geo.size.width * 0.82, height: geo.size.height)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .frame(height: 240)
        .accessibilityLabel(Text("\(title) photos"))
    }
}

private struct PlaceFeedAboutCard: View {
    let title: String
    let snapshot: KnowMapsPlaceSnapshot?
    let placeResponse: PlaceSearchResponse?
    let placeDetailsResponse: PlaceDetailsResponse?
    let isFetchingDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlaceFeedSectionHeader(title: "About")

            if let categoriesText, !categoriesText.isEmpty {
                Text(categoriesText)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if let summaryText, !summaryText.isEmpty {
                Text(summaryText)
            } else if isFetchingDetails {
                Text("Loading details…")
                    .foregroundStyle(.secondary)
            } else {
                Text("No description available.")
                    .foregroundStyle(.secondary)
            }

            if let hoursText, !hoursText.isEmpty {
                Label(hoursText, systemImage: "clock")
                    .labelStyle(.titleOnly)
                    .foregroundStyle(.secondary)
            }

            if let addressText, !addressText.isEmpty {
                Label(addressText, systemImage: "mappin")
                    .labelStyle(.titleOnly)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let ratingText {
                    Label(ratingText, systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let priceText {
                    Text(priceText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoriesText: String? {
        if let detailsCategories = placeDetailsResponse?.searchResponse.categories, !detailsCategories.isEmpty {
            return detailsCategories.joined(separator: ", ")
        }
        if let categories = placeResponse?.categories, !categories.isEmpty {
            return categories.joined(separator: ", ")
        }
        return nil
    }

    private var summaryText: String? {
        if let d = placeDetailsResponse?.description, !d.isEmpty {
            return d
        }
        return snapshot?.summary
    }

    private var hoursText: String? {
        placeDetailsResponse?.hours ?? snapshot?.hoursText
    }

    private var addressText: String? {
        if let address = placeDetailsResponse?.searchResponse.formattedAddress, !address.isEmpty {
            return address
        }
        if let address = snapshot?.location.formattedAddress, !address.isEmpty {
            return address
        }
        if let address = placeResponse?.formattedAddress, !address.isEmpty {
            return address
        }

        let parts = [
            snapshot?.location.neighborhood,
            snapshot?.location.locality,
            snapshot?.location.regionCode,
            snapshot?.location.countryCode
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private var ratingText: String? {
        if let details = placeDetailsResponse, details.rating > 0 {
            return String(format: "%.1f", details.rating)
        }
        if let r = snapshot?.rating {
            return String(format: "%.1f", r)
        }
        return nil
    }

    private var priceText: String? {
        let price = placeDetailsResponse?.price ?? snapshot?.priceTier
        guard let price else { return nil }
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

private struct PlaceFeedActionsRow: View {
    let isCompact: Bool
    let title: String
    let placeDetailsResponse: PlaceDetailsResponse?
    let isSaved: Bool
    let onToggleSave: () async -> Void
    let onShare: () -> Void
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlaceFeedSectionHeader(title: "Actions")

            HStack(spacing: 12) {
                Button {
                    Task(priority: .userInitiated) { await onToggleSave() }
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .modifier(IconOnlyIfCompact(isCompact: isCompact))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let tel = placeDetailsResponse?.tel, let url = PlaceAboutViewModel.getCallURL(tel: tel) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Call", systemImage: "phone")
                            .modifier(IconOnlyIfCompact(isCompact: isCompact))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let website = placeDetailsResponse?.website, let url = PlaceAboutViewModel.getWebsiteURL(website: website) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Website", systemImage: "link")
                            .modifier(IconOnlyIfCompact(isCompact: isCompact))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .modifier(IconOnlyIfCompact(isCompact: isCompact))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IconOnlyIfCompact: ViewModifier {
    let isCompact: Bool
    func body(content: Content) -> some View {
        if isCompact {
            content.labelStyle(.iconOnly)
        } else {
            content
        }
    }
}

private struct PlaceFeedDirectionsSection: View {
    let isCompact: Bool
    let title: String
    let address: String?
    let destinationCoordinate: CLLocationCoordinate2D?
    @Binding var showLookAround: Bool
    @ObservedObject var model: PlaceDirectionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlaceFeedSectionHeader(title: "Directions")

            if let address, !address.isEmpty {
                Text(address)
                    .foregroundStyle(.secondary)
            }

            if destinationCoordinate == nil {
                Text("No coordinates available for this place.")
                    .foregroundStyle(.secondary)
            } else if showLookAround, let lookAroundScene = model.lookAroundScene as? MKLookAroundScene {
                LookAroundPreview(initialScene: lookAroundScene)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if let destinationCoordinate {
                Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 1500, maximumDistance:250000)) {
                    Marker(title, coordinate: destinationCoordinate)
                    if let polyline = model.polyline {
                        MapPolyline(polyline)
                            .stroke(.blue, lineWidth: 6)
                    }
                }
                .mapControls {
                    MapPitchToggle()
                    MapUserLocationButton()
                    MapCompass()
                }
                .mapStyle(.standard)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Picker("Transport Type", selection: $model.rawTransportType) {
                Text(PlaceDirectionsViewModel.RawTransportType.Automobile.rawValue)
                    .tag(PlaceDirectionsViewModel.RawTransportType.Automobile)
                Text(PlaceDirectionsViewModel.RawTransportType.Walking.rawValue)
                    .tag(PlaceDirectionsViewModel.RawTransportType.Walking)
                Text(PlaceDirectionsViewModel.RawTransportType.Transit.rawValue)
                    .tag(PlaceDirectionsViewModel.RawTransportType.Transit)
            }
            .pickerStyle(.palette)

            HStack(spacing: 12) {
                if let source = model.source, let destination = model.destination {
                    let launchOptions = model.appleMapsLaunchOptions()
                    Button("Maps", systemImage: "map") {
                        MKMapItem.openMaps(with: [source, destination], launchOptions: launchOptions)
                    }
                    .buttonStyle(.bordered)
                }

                if model.lookAroundScene != nil {
                    Button(showLookAround ? "Directions" : "Look Around", systemImage: showLookAround ? "list.number" : "binoculars") {
                        showLookAround.toggle()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let steps = model.chatRouteResults, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(steps) { step in
                        Text(step.instructions)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedPhotosGrid: View {
    let isCompact: Bool
    let photoResponses: [PlacePhotoResponse]?
    let isFetchingDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlaceFeedSectionHeader(title: "Photos")

            if let photoResponses, !photoResponses.isEmpty {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompact ? 1 : 2)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(photoResponses) { response in
                        if let url = response.photoUrl() {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(CGFloat(response.aspectRatio), contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                } else if state.error != nil {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.secondary.opacity(0.12))
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(height: 160)
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.secondary.opacity(0.10))
                                        ProgressView()
                                    }
                                    .frame(height: 160)
                                }
                            }
                        }
                    }
                }
            } else if isFetchingDetails {
                Text("Loading photos…")
                    .foregroundStyle(.secondary)
            } else {
                Text("No photos found.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedTipsList: View {
    let tips: [PlaceTipsResponse]?
    let isFetchingDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlaceFeedSectionHeader(title: "Tips")

            if let tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(tips) { tip in
                        Text(tip.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else if isFetchingDetails {
                Text("Loading tips…")
                    .foregroundStyle(.secondary)
            } else {
                Text("No tips found.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedRelatedPlaces: View {
    let relatedPlaceResults: [ChatResult]
    let onTap: (ChatResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlaceFeedSectionHeader(title: "Related Places")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(relatedPlaceResults) { relatedPlace in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(relatedPlace.title)
                                .bold()
                            if let neighborhood = relatedPlace.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                Text(neighborhood).italic()
                            } else if let locality = relatedPlace.placeResponse?.locality, !locality.isEmpty {
                                Text(locality).italic()
                            }
                        }
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { onTap(relatedPlace) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PlaceFeedTastes: View {
    let isCompact: Bool
    let tastes: [String]
    let cachedTastesContains: (String) -> Bool
    let cachedTasteResult: (String) -> CategoryResult?
    let addTaste: @Sendable (String) async -> Void
    let removeTaste: @Sendable (CategoryResult) async -> Void

    var body: some View {
        Group {
            if tastes.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    PlaceFeedSectionHeader(title: "Features")

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: isCompact ? 2 : 3)
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(tastes, id: \.self) { taste in
                            let isSaved = cachedTastesContains(taste)
                            Button {
                                if isSaved {
                                    if let cached = cachedTasteResult(taste) {
                                        Task(priority: .userInitiated) { await removeTaste(cached) }
                                    }
                                } else {
                                    Task(priority: .userInitiated) { await addTaste(taste) }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isSaved ? "minus.circle" : "plus.circle")
                                    Text(taste)
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
