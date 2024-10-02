//
//  AddListItemView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/6/24.
//

import SwiftUI

struct AddListItemView: View {
    @EnvironmentObject public var cloudCache: CloudCache
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var chatHost: AssistiveChatHost
    @Binding public var presentingPopover: Bool
    
    @State private var textFieldData: String = ""
    @State private var selectedItems = Set<UUID>() // Use a Set to store multiple selected items
    
    var body: some View {
        VStack {
            Section {
                List(chatModel.cachedListResults, id: \.id, selection: $selectedItems) { parent in
                    HStack {
                        Text("\(parent.parentCategory)")
                        Spacer()
                    }
                }
                .refreshable {
                    Task {
                        do {
                            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
                .onChange(of: selectedItems) { oldValue, newValue in
                    for selectedItem in newValue {
                        
                        Task {
                            if let selectedPlaceChatResult = chatModel.selectedPlaceChatResult, let chatResult = chatModel.placeChatResult(for: selectedPlaceChatResult), let placeResponse = chatResult.placeResponse, let cachedListResult = chatModel.cachedListResult(for: selectedItem) {
                                
                                var userRecord = UserCachedRecord(recordId: "", group: "Place", identity:placeResponse.fsqID, title: placeResponse.name, icons: "", list:cachedListResult.list, section:chatResult.section.rawValue)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list, section:userRecord.section)
                                userRecord.setRecordId(to: record)
                                await chatModel.appendCachedCategory(with: userRecord)
                                await chatModel.refreshCachedResults()
                            }
                            
                        }
                    }
                }
                .padding()
            } header: {
                HStack {
                    TextField("Create new list", text: $textFieldData)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .onSubmit {
                            createNewList()
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding()
                    
                    Spacer()
                    Label("Create List", systemImage: "plus")
                        .onTapGesture {
                            createNewList()
                        }
                        .labelStyle(.iconOnly)
                    
                    Button("Done") {
                        Task {
                            try await chatModel.refreshCache(cloudCache: cloudCache)
                        }
                        presentingPopover.toggle()
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding()
    }
    
    private func createNewList() {
        guard !textFieldData.isEmpty else { return }
        
        Task {
            var userRecord = UserCachedRecord(
                recordId: "",
                group: "List",
                identity: textFieldData,
                title: textFieldData,
                icons: "",
                list: textFieldData,
                section: chatHost.section(for: textFieldData).rawValue
            )
            
            let record = try await chatModel.cloudCache.storeUserCachedRecord(
                for: userRecord.group,
                identity: userRecord.identity,
                title: userRecord.title,
                list: userRecord.list,
                section: userRecord.section
            )
            
            userRecord.setRecordId(to: record)
            await chatModel.appendCachedList(with: userRecord)
            await chatModel.refreshCachedResults()
        }
    }
}
