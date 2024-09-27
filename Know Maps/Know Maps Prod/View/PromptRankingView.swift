//
//  PromptRankingView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/27/24.
//

import Foundation

import SwiftUI

struct PromptRankingView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider

    @Binding public var contentViewDetail:ContentDetailView
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}
