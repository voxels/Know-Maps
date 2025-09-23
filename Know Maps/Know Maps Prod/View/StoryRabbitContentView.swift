//
//  StoryRabbitContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/23/25.
//

import SwiftUI
import AVFoundation
import AVKit


struct StoryRabbitContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @ObservedObject var settingsModel:AppleAuthenticationService
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @Binding  public var showOnboarding:Bool
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .frame(minWidth: geometry.size.width - 32, minHeight: geometry.size.height - 32)
                        .opacity(0.9)
                    #if os(iOS)
                    NavigationLink {
                        StoryRabbitView(chatModel: self.$chatModel, cacheManager: self.$cacheManager, modelController: self.$modelController,  searchSavedViewModel: $searchSavedViewModel, showOnboarding: self.$showOnboarding)
                    } label: {
                        Label("Generate", systemImage: "hare.fill")
                            .labelStyle(.iconOnly)
                            .tint(.primary)
                            .padding(16)
                            .glassEffect()
                    }
                    #elseif os(visionOS) || os(macOS)
                    Button(action: {
                        openWindow(id:"StoryRabbitView")
                    }, label: {
                        Label("Generate", systemImage: "hare.fill")
                    })
                    .labelStyle(.iconOnly)
                    .tint(.primary)
                    .padding(16)
                    .glassEffect()
                    #endif
                }
            }
        }
    }
}
