//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation
import MapKit
import NukeUI
//import GoogleMobileAds

struct PlacesList: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController: DefaultModelController
    
    @State private var lastTapPlaceID: ChatResult.ID? = nil
    @State private var lastTapTime: Date = .distantPast
    
    private func savePlace(_ result: ChatResult) async {
        await searchSavedViewModel.addPlace(parent: result.id, rating: 2, cacheManager: cacheManager, modelController: modelController)
    }
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    @ViewBuilder
    private func recommendedGrid(in geometry: GeometryProxy) -> some View {
        let sizeWidth: CGFloat = (sizeClass == .compact) ? 1 : 2
        let itemWidth: CGFloat = geometry.size.width / sizeWidth - 32
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(minimum:0, maximum: itemWidth), spacing: 16, alignment:.top),
            count: Int(sizeWidth)
        )
        
        ScrollView() {
            LazyVGrid(columns: columns) {
                ForEach(modelController.recommendedPlaceResults, id: \.id) { result in
                    let ar: CGFloat = CGFloat(result.recommendedPlaceResponse?.aspectRatio ?? 1.0)
                    let reservedHeight: CGFloat = itemWidth / ar
                    ZStack(alignment: .topTrailing) {
                        if let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(ar, contentMode: .fill)
                                        .frame(width: itemWidth, height: reservedHeight)
                                        .clipped()
                                } else if state.error != nil {
                                    ZStack {
                                        Rectangle().fill(.secondary.opacity(0.15))
                                        Image(systemName: "photo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: itemWidth, height: reservedHeight)
                                } else {
                                    ZStack {
                                        Rectangle().fill(.secondary.opacity(0.10))
                                        ProgressView()
                                    }
                                    .frame(width: itemWidth, height:reservedHeight)
                                }
                            }
                            .contentTransition(.opacity)
                            .frame(maxWidth: itemWidth, maxHeight:reservedHeight)
                        } else {
                            Color.clear
                                .frame(maxWidth: itemWidth, maxHeight:reservedHeight)
                        }
                        
                        VStack(alignment: .leading, spacing:4) {
                            if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                Text(result.title).bold()
                                Text(neighborhood).italic()
                            } else {
                                Text(result.title).bold()
                            }
                            if let placeResponse = result.recommendedPlaceResponse, !placeResponse.address.isEmpty {
                                Text(placeResponse.address)
                                Text(placeResponse.city)
                            }
                        }
                        .padding(16)
#if !os(visionOS)
                        .glassEffect(.regular, in: .rect(cornerRadius: 32))
                        .padding(16)
#else
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(16)
#endif

                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            Task {
                                await savePlace(result)
                            }
                        } label: {
                            Image(systemName: "star.fill")
                                .padding()
                        }
#if !os(visionOS)
                        .glassEffect()
#else
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
#endif
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
#if os(visionOS)
                    .hoverEffect(.lift)
#endif
                    
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.35), value: modelController.recommendedPlaceResults)
                    .simultaneousGesture(TapGesture().onEnded {
                        handlePlaceTap(result)
                    })
                }
            }
        }
    }
    
    @ViewBuilder
    private func placeResultsGrid(in geometry: GeometryProxy) -> some View {
        let sizeWidth: CGFloat = (sizeClass == .compact) ? 1 : 2
#if os(macOS) || os(visionOS)
        let columns: [GridItem] = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)), count: Int(sizeWidth))
#else
        let columns: [GridItem] = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth - 32.0)), count: Int(sizeWidth))
#endif
        
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 32) {
                ForEach(modelController.filteredPlaceResults) { result in
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading) {
                            Text(result.title).bold()
                            if let placeResponse = result.placeResponse, !placeResponse.formattedAddress.isEmpty {
                                Text(placeResponse.formattedAddress)
                            }
                        }
                        .padding()
                        .contentTransition(.opacity)
#if !os(visionOS)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#else
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#endif
                        
                        VStack { Spacer() }
                            .frame(width: 0, height: 0)
                            .overlay(alignment: .bottomTrailing) {
                                Button {
                                    Task {
                                        await savePlace(result)
                                    }
                                } label: {
                                    Image(systemName: "bookmark.badge.plus")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.title3)
                                        .padding(10)
                                }
#if !os(visionOS)
                                .background(.thinMaterial)
                                .clipShape(Circle())
#else
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
#endif
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
#if os(visionOS)
                    .hoverEffect(.lift)
#endif
                    .animation(.snappy(duration: 0.35), value: modelController.filteredPlaceResults)
                    .listRowBackground(Color.clear)
                    .listStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        handlePlaceTap(result)
                    })
                }
            }
            .padding()
        }
    }
    
    private func handlePlaceTap(_ result: ChatResult) {
        let now = Date()
        let debounce: TimeInterval = 0.2
        if lastTapPlaceID == result.id, now.timeIntervalSince(lastTapTime) < debounce {
            // Debounced identical re-tap
            return
        }
        lastTapPlaceID = result.id
        lastTapTime = now

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
    
    var body: some View {
        GeometryReader{ geometry in
            /*
             let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(geometry.size.width)
             BannerView(adSize)
             .frame(height: adSize.size.height)
             */
            if modelController.recommendedPlaceResults.count > 0 {
                recommendedGrid(in: geometry)
            } else if modelController.placeResults.count > 0 {
                placeResultsGrid(in: geometry)
            } else if !modelController.queryParametersHistory.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Spacer()
                    if modelController.isRefreshingPlaces {
                        let message = modelController.fetchMessage.isEmpty ? "Searching…" : modelController.fetchMessage
                        ProgressView {
                            Text(message)
                        }
                        .progressViewStyle(.linear)
                        .padding()
                    } else {
                        Text(modelController.fetchMessage)
                            .font(.caption)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}

