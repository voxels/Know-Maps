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
    @ObservedObject public var chatHost:AssistiveChatHost
    @Binding public var presentingPopover:Bool

    @State private var textFieldData:String = ""
    var body: some View {
            VStack {
                Section {
                    List(chatModel.cachedListResults, selection:$chatModel.selectedListCategoryResult ) { parent in
                        HStack {
                            Text("\(parent.parentCategory)")
                            Spacer()
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
                            if let newValue = newValue, let selectedPlaceChatResult = chatModel.selectedPlaceChatResult, let chatResult = chatModel.placeChatResult(for: selectedPlaceChatResult), let placeResponse = chatResult.placeResponse, let cachedListResult = chatModel.cachedListResult(for: newValue) {
                                
                                var userRecord = UserCachedRecord(recordId: "", group: "Place", identity:placeResponse.fsqID, title: placeResponse.name, icons: "", list:cachedListResult.list, section:chatResult.section.rawValue)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                userRecord.setRecordId(to: record)
                                chatModel.appendCachedCategory(with: userRecord)
                                chatModel.refreshCachedResults()
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
                                    var userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData, section:chatHost.section(for: textFieldData).rawValue)
                                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section: userRecord.section)
                                    userRecord.setRecordId(to: record)
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
                                var userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData, section:chatHost.section(for: textFieldData).rawValue)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                userRecord.setRecordId(to: record)
                                chatModel.appendCachedList(with: userRecord)
                                chatModel.refreshCachedResults()
                            }
                        }.labelStyle(.iconOnly)
                        Button("Done") {
                            Task {
                                try await chatModel.refreshCache(cloudCache: cloudCache)
                            }
                            presentingPopover.toggle()
                        }
                    }
                }
            }
            .padding(20)
        }
}
