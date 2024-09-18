//
//  SearchEditView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/18/24.
//

import SwiftUI

struct SearchEditView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}
