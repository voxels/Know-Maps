//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct PlacesList: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @State private var selectedItem: String?
    
    @Binding public var showMapsResultViewSheet:Bool
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    var body: some View {
        GeometryReader{ geometry in
            if chatModel.isFetchingResults {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView("Fetching results")
                        Spacer()
                    }
                    Spacer()
                }
            } else if chatModel.recommendedPlaceResults.count != 0 {
                ScrollView{
                    let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 2
#if os(macOS) || os(visionOS)
                    let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)),  count:Int(sizeWidth))
#else
                    let columns = Array(repeating: GridItem(.adaptive(minimum: UIScreen.main.bounds.size.width / sizeWidth)),  count:Int(sizeWidth))
#endif
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(chatModel.filteredRecommendedPlaceResults){ result in
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
                                if let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            HStack {
                                                Spacer()
                                                ProgressView()
                                                Spacer()
                                            }
                                            
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
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
                            .background(.thinMaterial)
                            .cornerRadius(16)
                            .onTapGesture {
                                chatModel.selectedPlaceChatResult = result.id
                            }
                        }
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            showMapsResultViewSheet.toggle()
                        } label: {
                            Label("Show Map", systemImage: "map")
                        }
                    }
                }
            } else if chatModel.placeResults.count != 0 {
                ScrollView{
                    let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 2
#if os(macOS) || os(visionOS)
                    let columns = Array(repeating: GridItem(.adaptive(minimum: geometry.size.width / sizeWidth)),  count:Int(sizeWidth))
#else
                    let columns = Array(repeating: GridItem(.adaptive(minimum: UIScreen.main.bounds.size.width / sizeWidth)),  count:Int(sizeWidth))
#endif
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(chatModel.filteredPlaceResults) { result in
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
                                if let url = result.placeDetailsResponse?.photoResponses?.first?.photoUrl() {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            HStack {
                                                Spacer()
                                                ProgressView()
                                                Spacer()
                                            }
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
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
                            .background(.thinMaterial)
                            .cornerRadius(16)
                            .onTapGesture {
                                chatModel.selectedPlaceChatResult = result.id
                            }
                        }
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}
