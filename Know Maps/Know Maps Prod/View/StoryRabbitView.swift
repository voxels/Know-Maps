//
//  StoryRabbitView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/23/25.
//

import SwiftUI

struct StoryRabbitView: View {
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @Binding public var showOnboarding:Bool
    
    @State public var storyController:StoryRabbitController?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .frame(minWidth:geometry.size.width, minHeight:geometry.size.height)
                    .background()
                    .edgesIgnoringSafeArea(.all)
                if let storyController {
                    switch storyController.playerState {
                    case .loading:
                        HStack(alignment: .center) {
                            ProgressView()
                                .progressViewStyle(.automatic)
                                .padding(16)
                                .glassEffect()
                        }
                    case .playing:
                        HStack(alignment: .center) {
                            
                        }
                    case .paused:
                        HStack(alignment: .center){
                            
                        }
                    case .finished:
                        HStack(alignment: .center){
                            
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .colorScheme(.dark)
            .task {
                storyController = StoryRabbitController(chatModel: chatModel, cacheManager: cacheManager, modelController: modelController, searchSavedViewModel: searchSavedViewModel, showOnboarding: showOnboarding, playerState: .loading, backgroundTask: UIBackgroundTaskIdentifier.init(rawValue: Int.random(in: 0..<Int.max)))
                storyController?.call(method: .createFromSingle)
            }
            .onChange(of:storyController?.playerState) {
                if let storyController = storyController {
                    switch storyController.playerState {
                    case .loading:
                        print("Loading")
                    case .playing:
                        print("Playing")
                    case .paused:
                        print("Paused")
                    case .finished:
                        print("Finished")
                    }
                }
            }
        }
    }
}
