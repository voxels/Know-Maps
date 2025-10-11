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
    @Binding var modelController:DefaultModelController
    @Binding public var showMapsResultViewSheet:Bool
    
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
                    
                    NavigationLink(value: result.id) {
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
                                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                    } else {
                                        ZStack {
                                            Rectangle().fill(.secondary.opacity(0.10))
                                            ProgressView()
                                        }
                                        .frame(width: itemWidth, height:reservedHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                    }
                                }
                                .contentTransition(.opacity)
                                .frame(maxWidth: itemWidth, maxHeight:reservedHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
#if os(visionOS)
                                .hoverEffect(.lift)
#endif
                            } else {
                                Color.clear
                                    .frame(maxWidth: itemWidth, maxHeight:reservedHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
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
#endif
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .gridCellAnchor(.top)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        modelController.selectedPlaceChatResult = result.id
                        Task { @MainActor in
                            await modelController.fetchPlaceDetailsIfNeeded(for: result, cacheManager: cacheManager)
                        }
                    })
                    .animation(.snappy(duration: 0.35), value: modelController.recommendedPlaceResults)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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
                    NavigationLink(value: result.id) {
                        VStack(alignment: .leading) {
                            Text(result.title).bold()
                            if let placeResponse = result.placeResponse, !placeResponse.formattedAddress.isEmpty {
                                Text(placeResponse.formattedAddress)
                            }
                        }
                        .padding()
                        .contentTransition(.opacity)
#if !os(visionOS)
                        .glassEffect()
#else
                        .hoverEffect(.lift)
#endif
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        modelController.selectedPlaceChatResult = result.id
                        Task { @MainActor in
                            await modelController.fetchPlaceDetailsIfNeeded(for: result, cacheManager: cacheManager)
                        }
                    })
                    .animation(.snappy(duration: 0.35), value: modelController.filteredPlaceResults)
                    .listRowBackground(Color.clear)
                    .listStyle(.plain)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .padding()
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
            }
            else if !modelController.queryParametersHistory.isEmpty {
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color(.systemBackground))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: modelController.locationResults), let _ = locationChatResult.location {
                    
                        VStack(alignment:.center, spacing: 12) {
                            Spacer()
                            if modelController.searchTimedOut {
                                Text("No Results Found")
                                    .padding()
                            } else {
                                Text(modelController.fetchMessage)
                                    .font(.caption)
                                    .padding()
                                .padding()
                            }
                            
                            let recCount = modelController.recommendedPlaceResults.count
                            let placeCount = modelController.placeResults.count
                            if recCount > 0 || placeCount > 0 {
                                EmptyView()
                                    .onAppear {
                                        modelController.cancelSearchTimeout()
                                        modelController.updateFoundResultsMessage(locationName: locationChatResult.locationName)
                                    }
                            } else {
                                EmptyView()
                            }
                            Spacer()
                        }
                    } else {
                        VStack(alignment:.center, spacing: 12) {
                            Spacer()
                            if modelController.searchTimedOut {
                                Text("No Results Found")
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
        .onDisappear {
            modelController.cancelSearchTimeout()
        }
    }
}
