//
//  StoryRabbitMapView.swift
//  hopit
//
//  Created by Michael A Edgcumbe on 10/3/25.
//

import SwiftUI
import MapKit
import AppIntents

struct StoryRabbitMapView: View {
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @State private var sheetIsPresented:Bool = true
    @State private var searchText:String = ""
    @State private var currentLocation:CLLocationCoordinate2D? = nil
    @State private var currentLocationName:String? = nil
    @State private var lookupTask: Task<Void, Never>?
    @State private var selectedTour:Tour? = nil
    @State private var currentPOIs:[POI] = []
    @State private var currentTours:[Tour] = []
    @State private var navigateToPlayer = false
    @State private var isPlayerActive = false // Track if player is active
    
    var body: some View {
        
            MapReader(content: { proxy in
                Map(initialPosition: .userLocation(fallback: .automatic))
                    .ignoresSafeArea()
                    .onMapCameraChange(frequency: .onEnd) { context in
                        let coord = context.region.center
                        self.currentLocation = coord
                        Task { @MainActor in
                            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                            do {
                                let firstResult = try await modelController.locationService.lookUpLocation(location).first
                                self.currentLocationName = firstResult.map { String(localized: $0.displayRepresentation.title) } ?? "Current Location"
                                sheetIsPresented = true
                            } catch {
                                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                            }
                        }
                    }
                    .sheet(isPresented: Binding(
                        get: { sheetIsPresented && !isPlayerActive && !navigateToPlayer },
                        set: { sheetIsPresented = $0 }
                    )) {
                        List {
                            Section {
                                ForEach(currentTours){ tour in
                                    Button {
                                        selectedTour = tour
                                        sheetIsPresented = false
                                        navigateToPlayer = true
                                    } label: {
                                        HStack{
                                            TourImageView(tour: tour)
                                            VStack (alignment: .leading) {
                                                Text(tour.title)
                                                    .font(.headline)
                                                if let description = tour.short_description {
                                                    Text(description)
                                                        .font(.subheadline)
                                                }
                                            }
                                            .foregroundStyle(Color(.label))
                                            .padding(.horizontal)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(.systemBackground))
                                        .contentShape(.rect(cornerRadius: 16))
                                        .clipShape(.rect(cornerRadius: 16))
                                    }
                                    .listRowBackground(Color.clear)
                                }
                            }  header: {
                                VStack(alignment:.leading) {
                                    if let currentLocationName {
                                        Text(currentLocationName)
                                            .font(.title)
                                    } else {
                                        Text("Current Location")
                                            .font(.title)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .listStyle(.plain)
                        .padding(.top)
                        .presentationDetents([.fraction(0.25), .medium, .large])
                        .searchable(text: $searchText, placement:.toolbarPrincipal, prompt:"Find a tour")
                    }
                    .fullScreenCover(isPresented: $navigateToPlayer) {
                        StoryRabbitPlayerView(
                            chatModel: $chatModel,
                            cacheManager: $cacheManager,
                            modelController: $modelController,
                            searchSavedViewModel: $searchSavedViewModel,
                            selectedTour: $selectedTour, currentPOIs: $currentPOIs
                        )
                        .onAppear {
                            isPlayerActive = true
                        }
                        .onDisappear {
                            isPlayerActive = false
                            navigateToPlayer = false
                            // Re-show sheet when returning from player
                            sheetIsPresented = true
                        }
                    }
                    .onAppear(){
                        if !isPlayerActive {
                            sheetIsPresented = true
                        }
                    }
                    .task {
                        do {
                            let results = try await SupabaseService.shared.fetchPOIsAndToursForUI()
                            currentPOIs = results.0
                            currentTours = results.1
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
                        }
                    }
            })
        }
}

struct TourImageView: View {
    let tour: Tour
    @State private var imageURL: URL?
    @State private var isLoading = true
    
    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } placeholder: {
            if isLoading {
                ProgressView()
                    .frame(width: 60, height: 60)
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
            }
        }
        .task {
            do {
                imageURL = try await tour.downloadImage()
                isLoading = false
            } catch {
                print("Error downloading tour image: \(error)")
                isLoading = false
            }
        }
    }
}

