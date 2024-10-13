//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation
import MapKit
//import GoogleMobileAds

struct PlacesList: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding  public var showMapsResultViewSheet:Bool
    @State private var selectedItem: String?
    
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    var body: some View {
        GeometryReader{ geometry in
            VStack {
                /*
                 let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(geometry.size.width)
                 BannerView(adSize)
                 .frame(height: adSize.size.height)
                 */
                if modelController.recommendedPlaceResults.count > 0 {
                    ScrollView{
                        let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 3
#if os(macOS) || os(visionOS)
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)),  count:Int(sizeWidth))
#else
                        let columns = Array(repeating: GridItem(.adaptive(minimum: UIScreen.main.bounds.size.width / sizeWidth),spacing:16, alignment: .top),  count:Int(sizeWidth))
#endif
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(modelController.recommendedPlaceResults, id:\.id){ result in
                                VStack(alignment:.leading, content: {
                                    ZStack {
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
                                        }.padding()
                                    }
                                    if let aspectRatio = result.recommendedPlaceResponse?.aspectRatio, let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                    ProgressView()
                                                    .padding()
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                    .scaledToFit()
                                            case .failure:
                                                EmptyView()
                                            @unknown default:
                                                // Since the AsyncImagePhase enum isn't frozen,
                                                // we need to add this currently unused fallback
                                                // to handle any new cases that might be added
                                                // in the future:
                                                EmptyView()
                                            }
                                        }
                                    }
                                })
                                .background()
                                .cornerRadius(16)
                                .onTapGesture {
                                    if modelController.selectedPlaceChatResult == result.id {
                                        modelController.selectedPlaceChatResult = nil
                                        DispatchQueue.main.async{
                                            modelController.selectedPlaceChatResult = result.id
                                        }
                                    } else {
                                        if let placeChatResult = modelController.placeChatResult(for: result.id), placeChatResult.placeDetailsResponse == nil {
                                            modelController.isRefreshingPlaces = true
                                            modelController.fetchMessage = "Searching"
                                            Task(priority:.userInitiated) {
                                                try await chatModel.didTap(placeChatResult: placeChatResult, filters:searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                                                await MainActor.run {
                                                    modelController.isRefreshingPlaces = false
                                                }
                                            }
                                        }
                                        else {
                                            modelController.selectedPlaceChatResult = result.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    
                } else if modelController.placeResults.count > 0 {
                    ScrollView{
                        let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 3
#if os(macOS) || os(visionOS)
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)),  count:Int(sizeWidth))
#else
                        let columns = Array(repeating: GridItem(.adaptive(minimum: UIScreen.main.bounds.size.width / sizeWidth)),  count:Int(sizeWidth))
#endif
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(modelController.filteredPlaceResults) { result in
                                VStack(alignment:.leading, content: {
                                    ZStack {
                                        VStack(alignment: .leading) {
                                            Text(result.title).bold()
                                            if let placeResponse = result.placeResponse, !placeResponse.address.isEmpty {
                                                Text(placeResponse.address)
                                                Text(placeResponse.locality)
                                            }
                                        }.padding()
                                    }
                                    if let aspectRatio = result.placeDetailsResponse?.photoResponses?.first?.aspectRatio, let url = result.placeDetailsResponse?.photoResponses?.first?.photoUrl() {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                    ProgressView()
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                    .scaledToFit()
                                            case .failure:
                                                EmptyView()
                                            @unknown default:
                                                // Since the AsyncImagePhase enum isn't frozen,
                                                // we need to add this currently unused fallback
                                                // to handle any new cases that might be added
                                                // in the future:
                                                EmptyView()
                                            }
                                        }
                                    }
                                })
                                .background()
                                .cornerRadius(16)
                                .onTapGesture {
                                    if modelController.selectedPlaceChatResult == result.id {
                                        modelController.selectedPlaceChatResult = nil
                                        DispatchQueue.main.async {
                                            modelController.selectedPlaceChatResult = result.id
                                        }
                                    } else {
                                        modelController.selectedPlaceChatResult = result.id
                                    }
                                }
                            }
                        }
                    }.padding()
                } else {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: modelController.filteredLocationResults(cacheManager: cacheManager)), !locationChatResult.locationName.isEmpty {
                                Text("No places near \(locationChatResult.locationName) matching query.")
                            } else {
                                Text("No places nearby matching query.")
                            }
                            Spacer()
                        }.frame(maxWidth: .infinity, alignment: .init(horizontal: .center, vertical: .center))
                        Spacer()
                    }.frame(maxWidth: .infinity, alignment: .init(horizontal: .center, vertical: .center))
                        .padding()
                }
            }
            .background(.regularMaterial)
            .ignoresSafeArea(.all, edges: .horizontal)
        }
    }
}
