//
//  StoryRabbitView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/23/25.
//

import SwiftUI
internal import AVFoundation

struct StoryRabbitPlayerView: View {
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @Binding var selectedTour:Tour?
    @State private var selectedPOI: POI = POI(id: 0, tour_id: 0, title: "", description: nil, latitude: 0, longitude: 0, script: "", audio_path: "", image_path: nil, order:1 )
    
    var body: some View {
        GeometryReader { geometry in
            NowPlayingQueueView(selectedTour: $selectedTour, selectedPOI: $selectedPOI, pois:modelController.currentPOIs)
            .task {
                if let tour = selectedTour, let firstPOI = modelController.currentPOIs.filter({$0.tour_id == tour.id}).first {
                    selectedPOI = firstPOI
                }
            }
            .onChange(of: modelController.currentPOIs) { oldValue, newValue in
                if let tour = selectedTour, let firstPOI = newValue.filter({$0.tour_id == tour.id}).first {
                    selectedPOI = firstPOI
                }
            }
        }
    }
}
