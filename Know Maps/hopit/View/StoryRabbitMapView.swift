//
//  StoryRabbitMapView.swift
//  hopit
//
//  Created by Michael A Edgcumbe on 10/3/25.
//

import SwiftUI
import MapKit

struct StoryRabbitMapView: View {
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @State private var sheetIsPresented:Bool = true
    @State private var popoverIsPresented:Bool = false
    @State private var selectedTour:String? = nil
    @State private var searchText:String = ""
    
    var body: some View {
        MapReader(content: { proxy in
            Map(initialPosition: .userLocation(fallback: .automatic))
                .ignoresSafeArea()
                .popover(isPresented: $popoverIsPresented) {
                    StoryRabbitPlayerView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel)
                }
                .sheet(isPresented: $sheetIsPresented) {
                        List{
                            Section {
                                ForEach(modelController.currentTours){ tour in
                                    Button{
                                        popoverIsPresented = true
                                    } label: {
                                        HStack{
                                            if let imagePath = tour.image_path {
                                                
                                            } else {
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .frame(width: 60, height: 60, alignment: .center)
                                            }
                                            Spacer()
                                            VStack (alignment: .leading) {
                                                Text(tour.title)
                                                    .font(.headline)
                                                if let description = tour.short_description {
                                                    Text(description)
                                                        .font(.subheadline)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding()
                                    .glassEffect()
                                }
                            }  header: {
                                VStack(alignment:.leading) {
                                    let location = modelController.locationProvider.currentLocation()
                                    let name = "Current Location"
                                    Text(name)
                                        .font(.title)
                                    Text("311 11th Ave, New York, NY 10001")
                                        .font(.title2)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listRowBackground(Color.clear)
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

