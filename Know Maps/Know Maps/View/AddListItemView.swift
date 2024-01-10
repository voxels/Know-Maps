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
    @Binding public var resultId:ChatResult.ID?

    @State private var textFieldData:String = ""
    var body: some View {
        if let resultId = resultId, let chatResult = chatModel.placeChatResult(for: resultId) {
            VStack {
                Section {
                    List(chatModel.filteredSuggestedListRecords, selection:$chatModel.selectedSuggestedListRecord) { listRecord in
                        HStack {
                            Text(listRecord.title)
                   
                            Spacer()
                            Label("List to save", systemImage: "star")
                                .labelStyle(.iconOnly)
                                .onTapGesture {
                                    print("Tap")
                                }
                        }
                    }.padding(10)
                } header: {
                    TextField("Add to list", text: $textFieldData)
                        .textFieldStyle(.roundedBorder)
                }
            }.padding(20)
                .onAppear {
                    Task { @MainActor in
                        try await chatModel.refreshSuggestedLists(cloudCache: cloudCache, with: chatResult)
                    }
                }
        } else {
            ContentUnavailableView("No place selected", systemImage: "")
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return AddListItemView(chatModel: chatModel, resultId: .constant(nil))
}
