//
//  SearchTasteView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/11/24.
//

import SwiftUI

struct SearchTasteView: View {
    @ObservedObject public var model:ChatResultViewModel
    
    var body: some View {
        List(model.tasteResults, selection: $model.selectedTasteCategoryResult) { parent in
            HStack {
                Text("\(parent.parentCategory)")
                Spacer()
                if let chatResults = parent.categoricalChatResults, chatResults.count == 1, model.cloudCache.hasPrivateCloudAccess {
                    Label("Save", systemImage:"star.fill")
                        .labelStyle(.iconOnly)
                        .onTapGesture {
                            
                        }
                }
            }
        }
        .task {
            do {
                try await model.refreshTastes()
            } catch {
                    model.analytics?.track(name: "error \(error)")
                    print(error)
            }
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)

    return SearchTasteView(model: chatModel)
}
