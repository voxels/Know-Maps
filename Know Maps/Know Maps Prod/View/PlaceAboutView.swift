//
//  PlaceContantView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//
import SwiftUI
import CoreLocation
import MapKit
import CallKit

struct PlaceAboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject var chatModel:ChatResultViewModel
    @ObservedObject var cacheManager:CloudCacheManager
    @ObservedObject var modelController:DefaultModelController
    @Binding var resultId:ChatResult.ID?
    @Binding var tabItem: Int
    var viewModel: PlaceAboutViewModel = PlaceAboutViewModel()

    static let defaultPadding: CGFloat = 8
    static let mapFrameConstraint: Double = 50000
    static let buttonHeight: Double = 44
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    if let resultId = resultId, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                        
                        // Title and Map
                        let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                        let title = placeResponse.name
                        
                        Text(title)
                            .font(.headline)
                            .padding()
                        
                        Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 5000, maximumDistance: 250000), interactionModes: [.zoom, .rotate]) {
                            Marker(title, coordinate: placeCoordinate.coordinate)
                        }
                        .mapStyle(.hybrid)
                        .frame(minHeight: geo.size.height / 2.0)
                        .cornerRadius(16)
                        .padding()
                        
                        // Address and Categories
                        ZStack(alignment: .leading) {
                            Rectangle().foregroundStyle(.thinMaterial)
                                .cornerRadius(16)
                            VStack {
                                Text(placeResponse.categories.joined(separator: ", ")).italic()
                                    .padding(PlaceAboutView.defaultPadding)
                                
                                Label(placeResponse.formattedAddress, systemImage: "mappin")
                                    .multilineTextAlignment(.leading)
                                    .padding()
                                    .onTapGesture {
                                        tabItem = 1
                                    }
                            }
                            .padding()
                        }
                        .padding()
                        
                        // Action buttons
                        HStack {
                            // Save/Unsave button
                            ZStack {
                                Capsule()
                                    .foregroundStyle(.accent)
                                    .frame(height: PlaceAboutView.buttonHeight)
                                
                                let isSaved = cacheManager.cachedPlaces(contains: result.title)
                                Label(isSaved ? "Delete" : "Add to List", systemImage: isSaved ? "minus.circle" : "square.and.arrow.down")
                                    .onTapGesture {
                                        Task {
                                            await viewModel.toggleSavePlace(resultId: resultId, cacheManager:cacheManager, modelController: modelController)
                                        }
                                    }
                            }
                            
                            // Phone button
                            if let tel = placeDetailsResponse.tel {
                                ZStack {
                                    Capsule()
                                        .foregroundStyle(.accent)
                                        .frame(height: PlaceAboutView.buttonHeight)
                                    
                                    Label(tel, systemImage: "phone")
                                        .onTapGesture {
                                            if let url = viewModel.getCallURL(tel: tel) {
                                                openURL(url)
                                            }
                                        }
                                }
                            }
                            
                            // Website button
                            if let website = placeDetailsResponse.website, let url = viewModel.getWebsiteURL(website: website) {
                                ZStack {
                                    Capsule()
                                        .foregroundStyle(.accent)
                                        .frame(height: PlaceAboutView.buttonHeight)
                                    
                                    Label("Visit website", systemImage: "link")
                                        .onTapGesture {
                                            openURL(url)
                                        }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(PlaceAboutView.defaultPadding)
                    } else {
                        // Loading view
                        VStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
