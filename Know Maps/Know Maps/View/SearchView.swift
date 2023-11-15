//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var model:ChatResultViewModel

    var body: some View {
        EmptyView()
    }
}

#Preview {
    let chatHost = AssistiveChatHost()
    let model = ChatResultViewModel()
    return SearchView(chatHost: chatHost, model: model)
}
