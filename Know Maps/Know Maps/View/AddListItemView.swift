//
//  AddListItemView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/6/24.
//

import SwiftUI

struct AddListItemView: View {
    @EnvironmentObject public var cloudCache:CloudCache
    @ObservedObject public var chatModel:ChatResultViewModel

    @State private var textFieldData:String = ""
    var body: some View {
            VStack {
                Section {
                    List(chatModel.cachedListRecords, selection:$chatModel.selectedSuggestedListRecord) { listRecord in
                        HStack {
                            Text(listRecord.title)
                   
                            Spacer()
                            Label("List to save", systemImage: "plus")
                                .labelStyle(.iconOnly)
                                .onTapGesture {
                                    Task {
                                        if let selectedPlaceChatResult = chatModel.selectedPlaceChatResult, let chatResult = chatModel.placeChatResult(for: selectedPlaceChatResult), let placeResponse = chatResult.placeResponse {
                                            let userRecord = UserCachedRecord(recordId: "", group: "Place", identity:placeResponse.name, title: placeResponse.name, icons: "", list:listRecord.title)
                                            try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:listRecord.title)
                                            try await chatModel.refreshCachedLists(cloudCache: cloudCache)
                                            chatModel.refreshCachedResults()
                                        }
                                    }
                                }
                        }
                    }.padding(10)
                } header: {
                    HStack {
                        TextField("Create new list", text: $textFieldData)
                            .textFieldStyle(.roundedBorder)
                        Spacer()
                        Button("Create List", systemImage: "plus") {
                            Task {
                                let userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData)
                                try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                try await chatModel.refreshCachedLists(cloudCache: cloudCache)
                                chatModel.refreshCachedResults()
                            }
                        }.labelStyle(.iconOnly)
                    }
                }
            }.padding(20)
        }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return AddListItemView(chatModel: chatModel)
}
