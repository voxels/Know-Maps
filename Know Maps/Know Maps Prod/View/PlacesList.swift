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
    @State private var showingPopover:Bool = false
    @State private var selectedItem: String?
    
    @Binding public var showMapsResultViewSheet:Bool

    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    var body: some View {
        if chatModel.isFetchingResults {
            ZStack {
                ProgressView("Fetching results")
            }
        } else {
            GeometryReader { geo in
                ScrollView{
                    if !chatModel.filteredRecommendedPlaceResults.isEmpty {
                        let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 2
                        let columns = Array(repeating: GridItem(.adaptive(minimum: UIScreen.main.bounds.size.width / sizeWidth)),  count:Int(sizeWidth))
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
                                                ProgressView()
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .clipped()
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
                                    } else if let response = result.placeDetailsResponse, let photoResponses = response.photoResponses, let photo = photoResponses.first, let url = photo.photoUrl() {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                            case .failure:
                                                Image(systemName: "photo")
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
                    } else {
                        EmptyView()
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
            }
        }
    }
}
