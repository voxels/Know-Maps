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
#if os(macOS) || os(visionOS)
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth), spacing:16, alignment: .top),  count:Int(sizeWidth))
#else
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth),spacing:16, alignment: .top),  count:Int(sizeWidth))
#endif
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 32) {
                            ForEach(modelController.recommendedPlaceResults, id:\.id){ result in
                                VStack {
                                    ZStack(alignment: .bottomLeading) {
                                        if let aspectRatio = result.recommendedPlaceResponse?.aspectRatio, let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                            LazyImage(url: url) { state in
                                                if let image = state.image {
                                                    image.resizable()
                                                        .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                        .scaledToFit()
                                                } else if state.error != nil {
                                                    Image(systemName: "photo")
                                                } else {
                                                    ProgressView()
                                                        .padding()
                                                         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 16)
                                            .glassEffect(.regular, in:.rect(cornerRadius: 16))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 16)
                                        }
                                    }
                                }
                                Divider()
                            }
                        }
                        .animation(.snappy(duration: 0.35), value: modelController.recommendedPlaceResults)
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
                                .glassEffect()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                } else {
                    if !modelController.queryParametersHistory.isEmpty {
                        HStack(alignment: .center) {
                            if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: modelController.filteredLocationResults(cacheManager: cacheManager)) {
                                Text("Searching near \(locationChatResult.locationName)")
                            }
                        }
                    }
                }
            }
        }
    }
}

