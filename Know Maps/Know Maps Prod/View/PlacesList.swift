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
    
    // MARK: - Search Timeout Timer State
    @State private var searchTimedOut: Bool = false
    @State private var searchTimeoutDuration: TimeInterval = 5.0 // seconds; adjust as needed
    @State private var searchTimerProgress: TimeInterval = 0.0
    @State private var searchTimer: Timer? = nil
    
    private func startSearchTimer() {
        cancelSearchTimer()
        searchTimedOut = false
        searchTimerProgress = 0
        // Fire every 0.1s to smoothly update progress
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            searchTimerProgress += 0.1
            if searchTimerProgress >= searchTimeoutDuration {
                searchTimedOut = true
                cancelSearchTimer()
            }
        }
        // Ensure the timer runs on the main run loop common modes (e.g., while scrolling)
        RunLoop.main.add(searchTimer!, forMode: .common)
    }
    
    private func cancelSearchTimer() {
        searchTimer?.invalidate()
        searchTimer = nil
    }
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    @ViewBuilder
    private func recommendedGrid(in geometry: GeometryProxy) -> some View {
        let sizeWidth: CGFloat = (sizeClass == .compact) ? 1 : 2
        let itemWidth: CGFloat = geometry.size.width / sizeWidth
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(minimum:0, maximum: itemWidth - 16), spacing: 16, alignment:.top),
            count: Int(sizeWidth)
        )
        
        ScrollView() {
            LazyVGrid(columns: columns) {
                ForEach(modelController.recommendedPlaceResults, id: \.id) { result in
                    let ar: CGFloat = CGFloat(result.recommendedPlaceResponse?.aspectRatio ?? 1.0)
                    let reservedHeight: CGFloat = itemWidth / ar
                    
                    VStack {
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
                                .onTapGesture {
                                    if modelController.selectedPlaceChatResult == result.id {
                                        withAnimation {
                                            modelController.selectedPlaceChatResult = nil
                                        }
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                modelController.selectedPlaceChatResult = result.id
                                                modelController.section = 1
                                                modelController.addItemSection = 3
                                            }
                                        }
                                    } else {
                                        if let placeChatResult = modelController.placeChatResult(for: result.id), placeChatResult.placeDetailsResponse == nil {
                                            modelController.isRefreshingPlaces = true
                                            modelController.fetchMessage = "Fetching Place Details"
                                            Task(priority: .userInitiated) {
                                                try await chatModel.didTap(placeChatResult: placeChatResult, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                                                await MainActor.run {
                                                    modelController.addItemSection = 3
                                                    modelController.isRefreshingPlaces = false
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                Color.clear
                                    .frame(maxWidth: itemWidth, maxHeight:reservedHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            }
                            
                            VStack(alignment: .leading, spacing:16) {
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(.separator, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .gridCellAnchor(.top)
                    }
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
        let columns: [GridItem] = Array(repeating: GridItem(.adaptive(minimum: geometry.size.height / sizeWidth)), count: Int(sizeWidth))
#endif
        
        ScrollView(.horizontal) {
            LazyHGrid(rows: columns, alignment: .center, spacing: 32) {
                ForEach(modelController.filteredPlaceResults) { result in
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
#endif
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 1)
                    )
#if os(visionOS)
                    .hoverEffect(.lift)
#endif
                    .onTapGesture {
                        if let placeChatResult = modelController.placeChatResult(for: result.id), placeChatResult.placeDetailsResponse == nil {
                            modelController.isRefreshingPlaces = true
                            modelController.fetchMessage = "Fetching Place Details"
                            Task(priority: .userInitiated) {
                                try await chatModel.didTap(placeChatResult: placeChatResult, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                                await MainActor.run {
                                    modelController.isRefreshingPlaces = false
                                }
                            }
                        }
                    }
                    .animation(.snappy(duration: 0.35), value: modelController.filteredPlaceResults)
                    .listRowBackground(Color.clear)
                    .listStyle(.plain)
                    
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
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
            }
            else if !modelController.queryParametersHistory.isEmpty {
                ZStack(alignment: .center) {
                    if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: modelController.locationResults), let _ = locationChatResult.location {
                    
                        VStack(spacing: 12) {
                            Spacer()
                            if searchTimedOut {
                                Text("No Results Found")
                                    .padding()
                                #if !os(visionOS)
                                    .glassEffect()
                                #endif
                            } else {
                                VStack {
                                    Text(modelController.fetchMessage)
                                        .font(Font.subheadline.bold())
                                        .padding()
                                    #if !os(visionOS)
                                        .glassEffect()
                                    #endif

                                }
                                .padding()
                            }
                            
                            let recCount = modelController.recommendedPlaceResults.count
                            let placeCount = modelController.placeResults.count
                            if recCount == 0 && placeCount == 0 {
                                ProgressView(value: min(searchTimerProgress / max(searchTimeoutDuration, 0.0001), 1.0))
                                Text("\(Int(max(searchTimeoutDuration - searchTimerProgress, 0)))s")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            else {
                                Text("Found \(recCount) recommended and \(placeCount) places near \(locationChatResult.locationName).")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.headline)
                                    .onAppear { cancelSearchTimer() }
                            }
                            Spacer()
                        }
                        .onAppear {
                            startSearchTimer()
                        }
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            if searchTimedOut {
                                Text("No Results Found")
                                    .padding()
                                #if !os(visionOS)
                                    .glassEffect()
                                #endif

                            } else {
                                VStack {
                                    Text(modelController.fetchMessage)
                                        .font(Font.subheadline.bold())
                                        .padding()
                                    #if !os(visionOS)
                                        .glassEffect()
                                    #endif
                                }
                                .padding()
                            }
                            if modelController.recommendedPlaceResults.count == 0 && modelController.placeResults.count == 0 {
                                ProgressView(value: min(searchTimerProgress / max(searchTimeoutDuration, 0.0001), 1.0))
                                    .padding()
                                Text("\(Int(max(searchTimeoutDuration - searchTimerProgress, 0)))s")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding()
                                #if !os(visionOS)
                                    .glassEffect()
                                #endif
                            }
                            else {
                                Text("Found \(modelController.recommendedPlaceResults.count) recommended and \(modelController.placeResults.count) places.")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.headline)
#if !os(visionOS)
    .glassEffect()
#endif
                            }
                            Spacer()
                        }
                        .onChange(of: cacheManager.isRefreshingCache) { oldValue, newValue in
                            if !newValue, modelController.placeResults.count == 0 && modelController.recommendedPlaceResults.count == 0 {
                                startSearchTimer()
                            }
                        }
                    }
                }
            }
        }
    }
}

