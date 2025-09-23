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

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}
