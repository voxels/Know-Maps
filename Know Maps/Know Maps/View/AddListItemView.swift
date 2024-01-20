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
    @Binding public var presentingPopover:Bool

    @State private var textFieldData:String = ""
    var body: some View {
            VStack {
                Section {
                    List(chatModel.cachedListResults, selection:$chatModel.selectedListCategoryResult ) { parent in
                        HStack {
                            Text("\(parent.parentCategory)")
                            Spacer()
                            Label("List to save", systemImage: "plus")
                                .labelStyle(.iconOnly)
                                .onTapGesture {
                                    Task {
                                        presentingPopover.toggle()
                                        if let selectedPlaceChatResult = chatModel.selectedPlaceChatResult, let chatResult = chatModel.placeChatResult(for: selectedPlaceChatResult), let placeResponse = chatResult.placeResponse {
                                            
                                            let userRecord = UserCachedRecord(recordId: "", group: "Place", identity:placeResponse.fsqID, title: placeResponse.name, icons: "", list:parent.list)
                                            try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                            chatModel.appendCachedPlace(with: userRecord)
                                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }
                        }
                    }.refreshable {
                        Task {
                            do {
                                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                    }.onChange(of: chatModel.selectedListCategoryResult, { oldValue, newValue in
                        Task {
                            presentingPopover.toggle()
                            if let newValue = newValue, let selectedPlaceChatResult = chatModel.selectedPlaceChatResult, let chatResult = chatModel.placeChatResult(for: selectedPlaceChatResult), let placeResponse = chatResult.placeResponse, let cachedListResult = chatModel.cachedListResult(for: newValue) {
                                
                                let userRecord = UserCachedRecord(recordId: "", group: "Place", identity:placeResponse.fsqID, title: placeResponse.name, icons: "", list:cachedListResult.list)
                                try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                chatModel.appendCachedPlace(with: userRecord)
                                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                            }
                        }
                    })
                    .padding(10)
                } header: {
                    HStack {
                        TextField("Create new list", text: $textFieldData)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .onSubmit {
                                guard !textFieldData.isEmpty else {
                                    return
                                }
                                
                                Task {
                                    let userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData)
                                    try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                    chatModel.appendCachedList(with: userRecord)
                                    chatModel.refreshCachedResults()
                                }
                            }
                        Spacer()
                        Label("Create List", systemImage: "plus")
                            .onTapGesture {
                            guard !textFieldData.isEmpty else {
                                return
                            }
                            
                            Task { 
                                let userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData)
                                try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                chatModel.appendCachedList(with: userRecord)
                                chatModel.refreshCachedResults()
                            }
                        }.labelStyle(.iconOnly)
                    }
                }
            }
            .padding(20)
        }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return AddListItemView(chatModel: chatModel, presentingPopover: .constant(true))
}
