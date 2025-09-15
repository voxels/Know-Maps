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
    
    var body: some View {
        GeometryReader{ geometry in
            List {
                /*
                 let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(geometry.size.width)
                 BannerView(adSize)
                 .frame(height: adSize.size.height)
                 */
                if modelController.recommendedPlaceResults.count > 0 {
                        let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 3
                    
                    // Compute an approximate item width for this grid cell
                    let itemWidth = geometry.size.width / sizeWidth - 32
#if os(macOS) || os(visionOS)
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth), spacing:16, alignment: .top),  count:Int(sizeWidth))
#else
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth),spacing:16, alignment: .top),  count:Int(sizeWidth))
#endif
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 32) {
                            ForEach(modelController.recommendedPlaceResults, id:\.id){ result in
                                // Derive aspect ratio (fallback to 4:3 if missing)
                                let ar = CGFloat(result.recommendedPlaceResponse?.aspectRatio ?? (4.0/3.0))

                                let reservedHeight = itemWidth / ar

                                VStack {
                                    ZStack(alignment: .bottomLeading) {
                                        
                                        if let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                            LazyImage(url: url) { state in
                                                if let image = state.image {
                                                    image
                                                      .resizable()
                                                      .aspectRatio(ar, contentMode: .fill)
                                                      .frame(width: itemWidth, height: reservedHeight) // fixed size
                                                      .clipped()
                                                } else if state.error != nil {
                                                    ZStack {
                                                        Rectangle().fill(.secondary.opacity(0.15))
                                                        Image(systemName: "photo")
                                                            .font(.title2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    .frame(height: reservedHeight)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                } else {
                                                    ZStack {
                                                        Rectangle().fill(.secondary.opacity(0.10))
                                                        ProgressView()
                                                    }
                                                    .frame(height: reservedHeight)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                }
                                            }
                                            .contentTransition(.opacity)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
#if os(visionOS)
                                            .hoverEffect(.lift)
#endif
                                            .onTapGesture {
                                                if modelController.selectedPlaceChatResult == result.id {
                                                    withAnimation {
                                                        modelController.selectedPlaceChatResult = nil
                                                    }
                                                    DispatchQueue.main.async{
                                                        withAnimation {
                                                            modelController.selectedPlaceChatResult = result.id
                                                        }
                                                    }
                                                } else {
                                                    if let placeChatResult = modelController.placeChatResult(for: result.id), placeChatResult.placeDetailsResponse == nil {
                                                        modelController.isRefreshingPlaces = true
                                                        modelController.fetchMessage = "Fetching Place Details"
                                                        Task(priority:.userInitiated) {
                                                            try await chatModel.didTap(placeChatResult: placeChatResult, filters:searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                                                            await MainActor.run {
                                                                modelController.isRefreshingPlaces = false
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        } else {
                                            // Reserve space immediately to prevent reflow when image loads
                                            Color.clear
                                                .frame(height: reservedHeight)
                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        VStack(alignment: .leading) {
                                            if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                                Text(result.title).bold()
                                                Text(neighborhood).italic()
                                            } else{
                                                Text(result.title).bold()
                                            }
                                            if let placeResponse = result.recommendedPlaceResponse, !placeResponse.address.isEmpty {
                                                Text(placeResponse.address)
                                                Text(placeResponse.city)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        #if !os(visionOS)
                                        .glassEffect(.regular, in:.rect(cornerRadius: 16))
                                        #endif
                                        .padding(8)
                                    }
                                    .frame(width: itemWidth, height: reservedHeight) // fix container size
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(.separator, lineWidth: 1)
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .gridCellAnchor(.top)
                                Divider()
                            }
                        }
                        .animation(.snappy(duration: 0.35), value: modelController.recommendedPlaceResults)
                        .listRowBackground(Color.clear)
                } else if modelController.placeResults.count > 0 {
                        let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 3
#if os(macOS) || os(visionOS)
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)),  count:Int(sizeWidth))
#else
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)),  count:Int(sizeWidth))
#endif
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(modelController.filteredPlaceResults) { result in
                                VStack(alignment:.leading, content: {
                                    VStack(alignment: .leading) {
                                        Text(result.title).bold()
                                        if let placeResponse = result.placeResponse, !placeResponse.formattedAddress.isEmpty {
                                            Text(placeResponse.formattedAddress)
                                        }
                                    }.padding()
                                })
                                .contentTransition(.opacity)
#if !os(visionOS)
.glassEffect()
#endif
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(.separator, lineWidth: 1)
                                )
#if os(visionOS)
                                .hoverEffect(.lift)
#endif
                                .onTapGesture {
                                    if let placeChatResult = modelController.placeChatResult(for: result.id), placeChatResult.placeDetailsResponse == nil {
                                        modelController.isRefreshingPlaces = true
                                        modelController.fetchMessage = "Fetching Place Details"
                                        Task(priority:.userInitiated) {
                                            try await chatModel.didTap(placeChatResult: placeChatResult, filters:searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                                            await MainActor.run {
                                                modelController.isRefreshingPlaces = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .animation(.snappy(duration: 0.35), value: modelController.filteredPlaceResults)
                        .listRowBackground(Color.clear)
                } else {
                    if !modelController.queryParametersHistory.isEmpty {
                        HStack(alignment: .center) {
                            if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: modelController.filteredLocationResults(cacheManager: cacheManager)) {
                                Text("Searching near \(locationChatResult.locationName)")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}

