//
//  AddPromptView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI

struct AddPromptView: View {
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var addItemSection: Int
    @Binding public var multiSelection: Set<UUID>
    
    var body: some View {
        Text("Hello world")
    }
}

struct AddPromptToolbarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var addItemSection: Int
    @Binding public var multiSelection: Set<UUID>
    @Binding public var preferredColumn: NavigationSplitViewColumn
    
    var body: some View {
        if addItemSection == 1 {
            Button(action: {
                Task(priority:.userInitiated) {
                    for parent in multiSelection {
                        await viewModel.addCategory(
                            parent: parent, rating:2,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                    }
                    multiSelection.removeAll()
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(multiSelection.count == 0)
            .labelStyle(.titleAndIcon)
        } else if addItemSection == 2 {
            Button(action: {
                Task(priority:.userInitiated) {
                    for parent in multiSelection {
                        await viewModel.addTaste(
                            parent: parent, rating:2,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                    }
                    multiSelection.removeAll()
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(multiSelection.count == 0)
            .labelStyle(.titleAndIcon)
        }
    }
}
