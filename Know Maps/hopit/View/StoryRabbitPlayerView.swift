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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().fill(Color.black.opacity(0.1))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                if let audioData = modelController.currentAudioData  {
                    if let player = modelController.player {
                        if player.rate.isZero {
                            Button("Play", systemImage: "play") {
                                Task {
                                    await modelController.play(audioPathURL: audioData)
    //                                modelController.storyController.call(method: .playRabbithole)
                                }
                            }
                        } else {
                            Button("Pause", systemImage: "pause") {
                                modelController.pause()
                            }
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.automatic)
                            .padding(16)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(.automatic)
                        .padding(16)
                }
            }
            .task {
                if let poi = modelController.currentPOIs.first {
                    await modelController.audioPOIModel(for:poi)
                }
            }
        }
    }
}
