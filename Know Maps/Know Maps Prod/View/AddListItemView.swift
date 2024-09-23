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
                                
                                var userRecord = UserCachedRecord(recordId: "", group: "Place", identity:placeResponse.fsqID, title: placeResponse.name, icons: "", list:cachedListResult.list)
                                chatModel.appendCachedPlace(with: userRecord)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                userRecord.setRecordId(to: record)
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
                                    var userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData)
                                    chatModel.appendCachedList(with: userRecord)
                                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                    userRecord.setRecordId(to: record)
                                }
                            }
                        Spacer()
                        Label("Create List", systemImage: "plus")
                            .onTapGesture {
                            guard !textFieldData.isEmpty else {
                                return
                            }
                            
                            Task { 
                                var userRecord = UserCachedRecord(recordId: "", group: "List", identity: textFieldData, title: textFieldData, icons: "", list: textFieldData)
                                chatModel.appendCachedList(with: userRecord)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                userRecord.setRecordId(to: record)
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
    let featureFlags = FeatureFlags()

    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)

    return AddListItemView(chatModel: chatModel, presentingPopover: .constant(true))
}
