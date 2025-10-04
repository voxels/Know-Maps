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
    @State private var popoverIsPresented:Bool = false
    @State private var searchText:String = ""
    @State private var currentLocation:CLLocationCoordinate2D? = nil
    @State private var currentLocationName:String? = nil
    @State private var lookupTask: Task<Void, Never>?
    @State private var selectedTour:Tour? = nil

    var body: some View {
        GeometryReader { geometry  in
            ScrollViewReader { scrollViewProxy in
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
                                      self.currentLocationName = firstResult.map { String(localized: $0.displayRepresentation.title) } ?? "Unknown Location"
                                      sheetIsPresented = true
                                  } catch {
                                      modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                                  }
                              }
                          }
                        .popover(isPresented: $popoverIsPresented) {
                            StoryRabbitPlayerView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel,selectedTour: $selectedTour)
                        }
                        .sheet(isPresented: $sheetIsPresented) {
                            List{
                                Section {
                                    ForEach(modelController.currentTours){ tour in
                                        Button{
                                            selectedTour = tour
                                            popoverIsPresented = true
                                        } label: {
                                            HStack{
                                                if let imagePath = tour.image_path {
                                                    
                                                } else {
                                                    Image(systemName: "photo")
                                                        .resizable()
                                                        .frame(width: 60, height: 60, alignment: .center)
                                                        .aspectRatio(contentMode: .fit)
                                                }
                                                VStack (alignment: .leading) {
                                                    Text(tour.title)
                                                        .font(.headline)
                                                    if let description = tour.short_description {
                                                        Text(description)
                                                            .font(.subheadline)
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }  header: {
                                    VStack(alignment:.leading) {
                                        if let currentLocationName {
                                            Text(currentLocationName)
                                                .font(.title)
                                        } else {
                                            Text("Unknown Location")
                                                .font(.title)
                                        }
                                    }
                                }
                            }
                            .padding(.top)
                            .presentationDetents([.fraction(0.25), .medium, .large])
                            .searchable(text: $searchText, placement:.automatic, prompt:"Find a tour")
                            .searchSuggestions {
                                Text("Orson Wells Tours")
                            }
                        }
                        .onChange(of: popoverIsPresented) { _, newValue in
                            if !newValue {
                                sheetIsPresented = true
                            }
                        }
                        .onAppear(){
                            sheetIsPresented = true
                        }
                })
            }
        }
    }
}

